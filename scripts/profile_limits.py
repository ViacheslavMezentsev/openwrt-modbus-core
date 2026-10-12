"""Accepted host profile/assembly limits; not a total process RAM guarantee."""
from transport_states import integer

PROFILE_BYTES = 16384
PROFILE_RANGES = 64
PROFILE_COUNT = 16
TOTAL_RANGES = 256
DEVICE_COUNT = 32
RESULT_BYTES = 1024
FRAGMENTS = 16
CONSUMERS = 16
ASSEMBLY_BYTES = 8192


def payload_size(function, count):
    return 0 if function == 6 else (count + 7) // 8 if function <= 2 else count * 2


def check_read(request, max_count):
    if payload_size(request.function, request.count) > RESULT_BYTES:
        raise ValueError('logical result exceeds 1024 bytes')
    if (request.count + max_count - 1) // max_count > FRAGMENTS:
        raise ValueError('logical read exceeds 16 fragments')


class AssemblyPool:
    def __init__(self, limit=ASSEMBLY_BYTES):
        integer(limit, 1, ASSEMBLY_BYTES, 'assembly pool limit')
        self.limit = limit
        self.reservations = {}

    @property
    def used(self):
        return sum(self.reservations.values())

    def acquire(self, owner, size):
        integer(size, 0, RESULT_BYTES, 'reservation size')
        if owner in self.reservations:
            raise ValueError('duplicate reservation')
        if self.used + size > self.limit:
            return False
        self.reservations[owner] = size
        return True

    def release(self, owner):
        del self.reservations[owner]
