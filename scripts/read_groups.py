"""Host-only trusted read maps, FIFO grouping and all-or-nothing fan-out."""
from dataclasses import dataclass, replace
from transport_states import integer


@dataclass(frozen=True)
class ReadRange:
    function: int
    start: int
    count: int
    safe_read: bool = False
    mergeable: bool = False
    max_count: int = 1
    max_gap: int = 0

    def __post_init__(self):
        integer(self.function, 1, 4, 'read function')
        integer(self.start, 0, 65535, 'range start')
        integer(self.count, 1, 65536 - self.start, 'range count')
        integer(self.max_count, 1, 2000 if self.function <= 2 else 125, 'max_count')
        integer(self.max_gap, 0, self.count - 1, 'max_gap')
        if type(self.safe_read) is not bool or type(self.mergeable) is not bool:
            raise ValueError('range flags')
        if self.mergeable and not self.safe_read:
            raise ValueError('mergeable requires safe_read')


@dataclass(frozen=True, init=False)
class ReadMap:
    ranges: tuple

    def __init__(self, ranges):
        ranges = tuple(ranges)
        if not ranges or len(ranges) > 128 or any(not isinstance(r, ReadRange) for r in ranges):
            raise ValueError('1..128 typed ranges required')
        ordered = tuple(sorted(ranges, key=lambda r: (r.function, r.start)))
        for a, b in zip(ordered, ordered[1:]):
            if a.function == b.function and a.start + a.count > b.start:
                raise ValueError('overlapping map ranges')
        object.__setattr__(self, 'ranges', ordered)

    def locate(self, request):
        for r in self.ranges:
            if (request.function == r.function and r.start <= request.address
                    and request.address + request.count <= r.start + r.count):
                return r
        raise ValueError('read outside a single declared range')

    def authorize(self, request):
        if request.function == 6:
            return request  # not a write allowlist; existing model probe unchanged
        r = self.locate(request)
        if request.count > r.max_count and not r.safe_read:
            raise ValueError('unsafe read cannot be split automatically')
        return replace(request, safe_read=r.safe_read)


@dataclass(frozen=True)
class ReadGroup:
    entries: tuple
    wires: tuple
    start: int
    expiry: int
    address: int
    count: int


def plan(entries, read_map):
    """Consume only a contiguous compatible FIFO prefix, never skip a barrier.

    A read larger than the device limit is split without merging other consumers.
    All entries were authorized at enqueue; the immutable map is checked again.
    """
    first = entries[0]
    req = first.request
    if req.function == 6:
        return ReadGroup((first,), (req,), first.admitted, first.expiry, req.address, req.count)
    region = read_map.locate(req)
    selected = [first]
    low, high = req.address, req.address + req.count
    if not first.readback and region.mergeable and req.count <= region.max_count:
        for entry in entries[1:]:
            candidate = entry.request
            if (entry.readback or candidate.function != req.function
                    or candidate.device_id != req.device_id or candidate.unit != req.unit
                    or candidate.safe_read != req.safe_read):
                break
            if read_map.locate(candidate) != region:
                break
            left, right = candidate.address, candidate.address + candidate.count
            gap = max(0, left - high, low - right)
            new_low, new_high = min(low, left), max(high, right)
            if gap > region.max_gap or new_high - new_low > region.max_count:
                break
            selected.append(entry)
            low, high = new_low, new_high
    wires = tuple(replace(req, address=a, count=min(region.max_count, high - a))
                  for a in range(low, high, region.max_count))
    return ReadGroup(tuple(selected), wires, min(e.admitted for e in selected),
                     min(e.expiry for e in selected), low, high - low)


class Assembly:
    """Bounded to the authorized logical read; no partial success escapes."""
    def __init__(self, group):
        self.group = group
        self.index = 0
        self.parts = []
        self.attempts = self.sent_attempts = 0
        self.done = False

    @property
    def wire(self):
        return self.group.wires[self.index]

    def finish(self, result):
        if self.done:
            raise ValueError('group already finished')
        self.attempts += result.attempts
        self.sent_attempts += result.sent_attempts
        self.parts.append(result.data if result.outcome == 'ok' else b'')
        if result.outcome == 'ok' and self.index + 1 < len(self.group.wires):
            self.index += 1
            return ()
        self.done = True
        if result.outcome == 'expired' and self.sent_attempts:
            result = replace(result, outcome='timeout')
        data = b''
        bits = None
        if result.outcome == 'ok' and self.wire.function != 6:
            if self.wire.function <= 2:
                bits = []
                for wire, part in zip(self.group.wires, self.parts):
                    bits.extend((part[i // 8] >> (i % 8)) & 1 for i in range(wire.count))
            else:
                data = b''.join(self.parts)
        outputs = []
        for entry in self.group.entries:
            req = entry.request
            payload = b''
            offset = req.address - self.group.address
            if result.outcome == 'ok':
                if req.function == 6:
                    payload = result.data
                elif bits is not None:
                    packed = bytearray((req.count + 7) // 8)
                    for i in range(req.count):
                        packed[i // 8] |= bits[offset + i] << (i % 8)
                    payload = bytes(packed)
                else:
                    payload = data[offset * 2:(offset + req.count) * 2]
            outputs.append(replace(result, operation_id=req.operation_id,
                                   device_id=req.device_id, start=entry.admitted,
                                   attempts=self.attempts, sent_attempts=self.sent_attempts,
                                   data=payload))
        self.parts.clear()
        return tuple(outputs)
