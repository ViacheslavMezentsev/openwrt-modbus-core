"""Host composition of transport_states; no real I/O, IPC or wall clock.

Core 4.7 and 6.8.2/13/14/15. Optional trusted maps enable FIFO read grouping. Each pass consumes at most one bounded I/O event per endpoint.
"""
from collections import deque
from types import MappingProxyType
from dataclasses import dataclass
from transport_states import Result, integer, validate_request
from read_groups import ReadMap, ReadGroup, Assembly, plan


@dataclass(frozen=True)
class Entry:
    request: object
    admitted: int
    expiry: int
    periodic: object
    readback: bool = False


@dataclass(frozen=True)
class Event:
    kind: str
    data: object = None
    generation: object = None

    def validate(self):
        if self.kind not in ('setup', 'tx', 'tx_complete', 'rx', 'error'):
            raise ValueError('event kind')
        if self.kind == 'rx':
            if not isinstance(self.data, bytes) or len(self.data) > 512:
                raise ValueError('bounded RX event')
        elif self.kind == 'tx':
            integer(self.data, 0, 512, 'bounded TX event')
        elif self.data is not None:
            raise ValueError('unexpected event payload')


@dataclass(frozen=True)
class Pass:
    results: tuple
    consumed: tuple
    order: tuple
    transitions: dict
    io_bytes: dict
    ipc_serviced: int
    round_started: tuple


class Scheduler:
    def __init__(self, transports, *, queue_limit=32, quantum=10, ipc_limit=128, read_maps=None):
        integer(queue_limit, 1, 128, 'queue_limit')
        integer(quantum, 1, 100, 'quantum')
        integer(ipc_limit, 1, 128, 'ipc_limit')
        transports = tuple(transports)
        names = [t.transport_id for t in transports]
        if not transports or len(set(names)) != len(names):
            raise ValueError('endpoint identity')
        if sum(t.kind == 'rtu' for t in transports) > 3 or sum(t.kind == 'tcp' for t in transports) > 4:
            raise ValueError('endpoint limit')
        if any(t.op or t.results or t.now != 0 for t in transports):
            raise ValueError('scheduler takes fresh endpoints at time zero')
        self.ports = {t.transport_id: t for t in transports}
        self.queues = {name: deque() for name in names}
        self.queue_limit, self.quantum, self.ipc_limit = queue_limit, quantum, ipc_limit
        self.now = self.cursor = self.ipc_pending = self.round_number = 0
        self.members = frozenset()
        self.pending = set()
        self.read_maps = MappingProxyType(dict(read_maps or {}))
        if len(self.read_maps) > 32 or any(not isinstance(m, ReadMap) for m in self.read_maps.values()):
            raise ValueError('read maps')
        self.groups = {}
        self.devices = {}  # bounded static logical identity binding for this model

    def enqueue(self, name, request, *, expiry=None, periodic=None, readback=False):
        t = self.ports[name]
        validate_request(request, t.kind, logical=bool(self.read_maps))
        if type(readback) is not bool or (readback and request.function == 6):
            raise ValueError('readback flag')
        if self.read_maps and request.function != 6:
            if request.device_id not in self.read_maps:
                raise ValueError('missing device map')
            request = self.read_maps[request.device_id].authorize(request)
        if periodic is not None and (not isinstance(periodic, str) or not periodic or len(periodic) > 32):
            raise ValueError('periodic key')
        if expiry is not None:
            integer(expiry, 0, 2**53 - 1, 'expiry')
        key = (name, request.unit)
        if request.device_id in self.devices and self.devices[request.device_id] != key:
            raise ValueError('logical identity rebind')
        if request.device_id not in self.devices and (len(self.devices) >= 32 or key in self.devices.values()):
            raise ValueError('logical identity limit/alias')
        queue = self.queues[name]
        # One pending periodic read per plan; do not replace the original deadline.
        if periodic is not None:
            if readback or request.function not in (1, 2, 3, 4):
                raise ValueError('periodic reads only')
            for entry in queue:
                if entry.periodic == periodic:
                    original = entry.request
                    if (original.device_id, original.unit, original.function,
                        original.address, original.count, original.safe_read) != (
                        request.device_id, request.unit, request.function,
                        request.address, request.count, request.safe_read):
                        raise ValueError('periodic plan changed while pending')
                    return 'coalesced'
        if (any(e.request.operation_id == request.operation_id for e in
                self.groups[name].group.entries) if name in self.groups else False):
            raise ValueError('duplicate active consumer')
        if ((t.op and t.op.operation_id == request.operation_id) or
                any(e.request.operation_id == request.operation_id for e in queue)):
            raise ValueError('duplicate pending operation')
        active_consumers = len(self.groups[name].group.entries) if name in self.groups else 0
        if len(queue) + max(0, active_consumers - 1) >= self.queue_limit:
            return 'busy'
        deadline = min(self.now + t.operation_timeout,
                       self.now + t.operation_timeout if expiry is None else expiry)
        queue.append(Entry(request, self.now, deadline, periodic, readback))
        self.devices[request.device_id] = key
        return 'accepted'

    def post_ipc(self, count=1):
        integer(count, 1, self.ipc_limit, 'IPC count')
        if self.ipc_pending + count > self.ipc_limit:
            return False
        self.ipc_pending += count
        return True

    def _expire(self, name, results):
        t = self.ports[name]
        kept = deque()
        # Scan is bounded by queue_limit, including non-head expiry.
        for entry in self.queues[name]:
            if self.now >= entry.expiry:
                r = entry.request
                results.append(Result(r.operation_id, r.device_id, name, 'expired',
                                      0, 0, entry.admitted, self.now,
                                      'not_sent' if r.function == 6 else None))
                if r.device_id in t.samples:
                    t.samples[r.device_id]['valid'] = False
            else:
                kept.append(entry)
        self.queues[name] = kept

    def _event(self, t, event):
        if event.kind == 'setup':
            t.setup_done(event.generation)
        elif event.kind == 'tx':
            t.tx(event.data, event.generation)
        elif event.kind == 'tx_complete':
            t.tx_complete(event.generation)
        elif event.kind == 'rx':
            t.receive(event.data, event.generation)
        else:
            t.io_error(event.generation)

    def step(self, now, events=None):
        integer(now, self.now, 2**53 - 1, 'monotonic clock')
        events = {} if events is None else dict(events)
        for name, event in events.items():
            if name not in self.ports or not isinstance(event, Event):
                raise ValueError('event endpoint')
            event.validate()
        self.now = now
        names = tuple(self.ports)
        order = names[self.cursor:] + names[:self.cursor]
        self.cursor = (self.cursor + 1) % len(names)
        before = {n: t.transitions for n, t in self.ports.items()}
        io_bytes = dict.fromkeys(names, 0)
        results, consumed = [], []
        for name in order:
            t = self.ports[name]
            t.tick(now)  # at most three transitions, no retry loop
            self._expire(name, results)
            if name in events and t.transitions - before[name] <= 3:
                event = events[name]
                self._event(t, event)  # reserve up to five transitions
                consumed.append(name)
                io_bytes[name] = len(event.data) if event.kind == 'rx' else event.data if event.kind == 'tx' else 0
            completed = t.drain_results()
            if completed:
                assembly = self.groups.get(name)
                if assembly is None:
                    results.extend(completed)
                    self.pending.discard(name)
                else:
                    outputs = assembly.finish(completed[0])
                    if outputs:
                        results.extend(outputs)
                        del self.groups[name]
                        self.pending.discard(name)
                    else:
                        t.valid = False  # partial fragments are not a complete logical read
                        t.last_success = assembly.previous_success
            if name in self.groups and not t.op and now >= self.groups[name].group.expiry:
                assembly = self.groups.pop(name)
                req = assembly.wire
                expired = Result(req.operation_id, req.device_id, name, 'expired', 0, 0,
                                 assembly.group.start, now, None)
                results.extend(assembly.finish(expired))
                self.pending.discard(name)
                t.valid = False
        # A fixed RTU set lasts until every operation (including retries) terminates.
        eligible = [n for n in order if (self.queues[n] or n in self.groups) and self.ports[n].state == 'idle'
                    and self.ports[n].op is None and now >= self.ports[n].ready_at
                    and self.ports[n].transitions - before[n] <= 4]
        started = ()
        if not self.pending:
            started = tuple(n for n in eligible if self.ports[n].kind == 'rtu')
            self.members = frozenset(started)
            self.pending = set(started)
            if started:
                self.round_number += 1
        for name in eligible:
            t = self.ports[name]
            if t.kind == 'rtu' and name not in started and name not in self.pending:
                continue
            if name not in self.groups:
                entries = tuple(self.queues[name])
                head = entries[0]
                read_map = self.read_maps.get(head.request.device_id)
                group = (plan(entries, read_map) if read_map else
                         ReadGroup((head,), (head.request,), head.admitted, head.expiry,
                                   head.request.address, head.request.count))
                for _ in group.entries:
                    self.queues[name].popleft()
                self.groups[name] = Assembly(group)
                self.groups[name].previous_success = t.samples.get(
                    head.request.device_id, {}).get('last_success')
            assembly = self.groups[name]
            group = assembly.group
            if not t.admit(assembly.wire, group.expiry, admitted_at=group.start):
                raise AssertionError('eligible endpoint refused admission')
            if not t.begin() and not t.results:
                raise AssertionError('eligible endpoint failed to begin')
        serviced = min(8, self.ipc_pending)  # synthetic work units, not wire IPC
        self.ipc_pending -= serviced
        transitions = {n: self.ports[n].transitions - before[n] for n in names}
        assert all(n <= 8 for n in transitions.values()), transitions
        return Pass(tuple(results), tuple(consumed), order, transitions, io_bytes, serviced, started)

    def next_wait(self):
        """Maximum modeled wait; None means no work/timer and an external wakeup."""
        deadlines = []
        immediate = self.ipc_pending > 0
        for name, t in self.ports.items():
            deadlines.extend(e.expiry for e in self.queues[name])
            if t.op:
                deadlines.append(t.dop)
                if t.da is not None:
                    deadlines.append(t.da)
                if t.state == 'setup':
                    deadlines.append(t.setup_deadline)
                if t.state == 'retry':
                    deadlines.append(t.retry_at)
            if t.state == 'quarantine':
                deadlines.append(max(t.quarantine_end + 1, t.quiet_end))
            if name in self.groups and not t.op:
                deadlines.append(self.groups[name].group.expiry)
                if t.state == 'idle':
                    deadlines.append(t.ready_at)
            if self.queues[name] and t.state == 'idle' and (t.kind == 'tcp' or not self.pending):
                deadlines.append(t.ready_at)
        if immediate:
            return 0
        if not deadlines:
            return None
        return max(0, min(self.quantum, min(deadlines) - self.now))
