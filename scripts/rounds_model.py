"""Host-only discrete-event model; no serial, wall clock, sleep or runtime imports.

Requests represent already grouped operations. FIFO, deadline tie = timeout,
and service quantum are explicit model assumptions, not deployed defaults.
Outcomes are an oracle, NOT Modbus frames or evidence of RTU resynchronization.
"""
from dataclasses import dataclass


def natural(value, name, positive=False):
    if type(value) is not int or value < int(positive):
        raise ValueError(name)


@dataclass(frozen=True)
class Port:
    name: str
    physical: str  # synthetic identity; no filesystem path resolution
    available_at: int = 0


@dataclass(frozen=True)
class Request:
    id: str
    port: str
    unit: int
    ready_at: int
    timeout: int
    delay: object = None  # None: silent; otherwise abstract response delay
    outcome: str = 'ok'


class Model:
    """Finite workload, deterministic event jumps and independently timed ports."""
    def __init__(self, ports, *, mode='rounds', quantum=5, queue_limit=16,
                 max_requests=1000, max_steps=100000):
        if mode not in ('rounds', 'sequential'):
            raise ValueError('mode')
        for name, value in [('quantum', quantum), ('queue_limit', queue_limit),
                            ('max_requests', max_requests), ('max_steps', max_steps)]:
            natural(value, name, True)
        if not ports or len(ports) > 3:
            raise ValueError('model supports 1..3 ports')
        names, physical = set(), set()
        for port in ports:
            if not port.name or not port.physical or port.name in names or port.physical in physical:
                raise ValueError('duplicate/empty port identity')
            natural(port.available_at, 'available_at')
            names.add(port.name)
            physical.add(port.physical)
        self.ports = tuple(ports)
        self.mode, self.quantum, self.queue_limit = mode, quantum, queue_limit
        self.max_requests, self.max_steps = max_requests, max_steps

    def run(self, requests):
        requests = tuple(requests)
        if len(requests) > self.max_requests:
            raise ValueError('workload limit')
        names = {p.name for p in self.ports}
        ids = set()
        for request in requests:
            if not request.id or request.id in ids or request.port not in names:
                raise ValueError('request identity')
            ids.add(request.id)
            natural(request.unit, 'unit', True)
            if request.unit > 247:
                raise ValueError('unit')
            natural(request.ready_at, 'ready_at')
            natural(request.timeout, 'timeout', True)
            if request.delay is not None:
                natural(request.delay, 'delay')
            if request.outcome not in ('ok', 'error', 'disconnect'):
                raise ValueError('outcome')
        pending = sorted(enumerate(requests), key=lambda pair: (pair[1].ready_at, pair[0]))
        queues = {p.name: [] for p in self.ports}
        active, trace, results, cache = {}, [], [], {}
        now, cursor, round_id, steps = 0, 0, 0, 0
        next_service = self.quantum

        def emit(kind, **fields):
            trace.append(dict(kind=kind, at=now, round=round_id, **fields))

        def finish(request, outcome, started):
            result = dict(id=request.id, port=request.port, unit=request.unit,
                          outcome=outcome, started=started, at=now)
            results.append(result)
            emit('result', **{k: v for k, v in result.items() if k != 'at'})
            if started is not None:
                old = cache.get((request.port, request.unit), {})
                cache[(request.port, request.unit)] = dict(
                    valid=outcome == 'ok',
                    last_success=now if outcome == 'ok' else old.get('last_success'))

        while cursor < len(pending) or active or any(queues.values()):
            steps += 1
            if steps > self.max_steps:
                raise RuntimeError('simulation step budget exceeded')
            while cursor < len(pending) and pending[cursor][1].ready_at <= now:
                request = pending[cursor][1]
                cursor += 1
                if len(queues[request.port]) >= self.queue_limit:
                    finish(request, 'rejected', None)
                else:
                    queues[request.port].append(request)
                    emit('enqueue', id=request.id, port=request.port)
            had_active = bool(active)
            for port, (request, started, end, outcome) in list(active.items()):
                if end <= now:
                    finish(request, outcome, started)
                    del active[port]
            if had_active and not active:
                emit('barrier')
            # Represents one bounded service opportunity, not actual IPC throughput.
            if now >= next_service:
                emit('service')
                next_service = now + self.quantum
            if not active:
                chosen = [p for p in self.ports if queues[p.name] and p.available_at <= now]
                if self.mode == 'sequential':
                    chosen = chosen[:1]
                if chosen:
                    round_id += 1
                    emit('round_start', ports=[p.name for p in chosen])
                    for port in chosen:
                        request = queues[port.name].pop(0)
                        timed_out = request.delay is None or request.delay >= request.timeout
                        duration = request.timeout if timed_out else request.delay
                        outcome = 'timeout' if timed_out else request.outcome
                        active[port.name] = (request, now, now + duration, outcome)
                        emit('start', id=request.id, port=port.name, unit=request.unit)
            if cursor == len(pending) and not active and not any(queues.values()):
                break
            times = [entry[2] for entry in active.values()]
            if cursor < len(pending):
                times.append(pending[cursor][1].ready_at)
            times += [p.available_at for p in self.ports
                      if queues[p.name] and p.available_at > now]
            times.append(next_service)
            now = min(times)
        return dict(elapsed=now, trace=trace, results=results, cache=cache, steps=steps)
