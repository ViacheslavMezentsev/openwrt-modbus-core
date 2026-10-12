"""Host-only strict profile loader. No router paths are opened by default.

The caller supplies a trusted installation directory and explicit device bindings.
Only canonical referenced regular files are opened; no code execution or fallback.
"""
from dataclasses import dataclass
import json
import os
import re
import stat
from types import MappingProxyType
from read_groups import ReadMap, ReadRange
from profile_limits import PROFILE_BYTES, PROFILE_COUNT, TOTAL_RANGES, DEVICE_COUNT


_ID = re.compile(r'[a-z0-9][a-z0-9_-]{0,31}\Z')


def identifier(value):
    if not isinstance(value, str) or not _ID.fullmatch(value):
        raise ValueError('invalid profile/device id')
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key: ' + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError('non-JSON numeric constant')


def check_depth(text):
    # Schema needs root object -> array -> range object only. Bound parser nesting
    # before decoding; escaped quotes/brackets inside strings are not structure.
    depth = 0
    quoted = escaped = False
    for char in text:
        if quoted:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char in '[{':
            depth += 1
            if depth > 3:
                raise ValueError('profile nesting exceeds schema')
        elif char in ']}':
            depth -= 1


@dataclass(frozen=True)
class Profile:
    id: str
    read_map: ReadMap


def decode_profile(data, expected_id):
    identifier(expected_id)
    if not isinstance(data, bytes) or len(data) > PROFILE_BYTES:
        raise ValueError('profile byte limit')
    try:
        text = data.decode('utf-8')
        check_depth(text)
        document = json.loads(text, object_pairs_hook=unique_object,
                              parse_constant=reject_constant)
    except (UnicodeError, RecursionError) as exc:
        raise ValueError('invalid profile encoding/nesting') from exc
    if type(document) is not dict or set(document) != {'id', 'read_ranges'}:
        raise ValueError('profile fields')
    if identifier(document['id']) != expected_id:
        raise ValueError('filename/id mismatch')
    ranges = document['read_ranges']
    if type(ranges) is not list or any(type(x) is not dict for x in ranges):
        raise ValueError('read_ranges must be an array of objects')
    try:
        read_map = ReadMap(ReadRange(**x) for x in ranges)
    except TypeError as exc:
        raise ValueError('range fields') from exc
    return Profile(expected_id, read_map)


class ProfileStore:
    def __init__(self):
        self.profiles = MappingProxyType({})
        self.bindings = MappingProxyType({})
        self.maps = MappingProxyType({})

    def activate(self, directory, bindings, *, maintenance, active_operations=0):
        if maintenance is not True or type(active_operations) is not int or active_operations != 0:
            raise ValueError('idle maintenance required')
        if type(bindings) is not dict or len(bindings) > DEVICE_COUNT:
            raise ValueError('device binding limit/type')
        bindings = dict(bindings)
        for device, profile in bindings.items():
            identifier(device)
            identifier(profile)
        ids = set(bindings.values())
        if len(ids) > PROFILE_COUNT:
            raise ValueError('profile count limit')
        candidate = {}
        # A trusted catalogue has one canonical filename per ID. Package ownership
        # collisions must be rejected by the installer, not by overwriting files.
        root = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            for id in sorted(ids):
                fd = os.open(id + '.json', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=root)
                try:
                    info = os.fstat(fd)
                    if not stat.S_ISREG(info.st_mode) or info.st_size > PROFILE_BYTES:
                        raise ValueError('profile must be a bounded regular file')
                    chunks = bytearray()
                    while len(chunks) <= PROFILE_BYTES:
                        part = os.read(fd, PROFILE_BYTES + 1 - len(chunks))
                        if not part:
                            break
                        chunks.extend(part)
                    candidate[id] = decode_profile(bytes(chunks), id)
                finally:
                    os.close(fd)
        finally:
            os.close(root)
        if sum(len(p.read_map.ranges) for p in candidate.values()) > TOTAL_RANGES:
            raise ValueError('aggregate range limit')
        maps = {d: candidate[p].read_map for d, p in bindings.items()}
        # Single-threaded host activation: do not publish anything until all pass.
        self.profiles = MappingProxyType(candidate)
        self.bindings = MappingProxyType(bindings)
        self.maps = MappingProxyType(maps)
