"""Profile loader, atomic activation and assembly resource boundary tests."""
import json
from pathlib import Path
import tempfile
import unittest
from device_profiles import ProfileStore, decode_profile
from read_groups import ReadMap, ReadRange, WireSequence
from profile_limits import AssemblyPool
from transport_states import Transport, Request
from transport_scheduler import Scheduler
import test_read_groups as helpers


def document(id='sensor', count=1):
    return {'id': id, 'read_ranges': [dict(function=3, start=i, count=1,
                                          safe_read=True, max_count=1) for i in range(count)]}


def encode(doc):
    return json.dumps(doc).encode()


class Profiles(unittest.TestCase):
    def test_valid_profile_and_defaults(self):
        p = decode_profile(encode(document()), 'sensor')
        self.assertEqual(p.id, 'sensor')
        self.assertFalse(p.read_map.ranges[0].mergeable)
        self.assertEqual(p.read_map.ranges[0].max_gap, 0)

    def test_duplicate_keys_at_both_levels(self):
        for text in ('{"id":"sensor","id":"sensor","read_ranges":[]}',
                     '{"id":"sensor","read_ranges":[{"function":3,"start":0,"start":1,"count":1}]}'):
            with self.assertRaises(ValueError): decode_profile(text.encode(), 'sensor')

    def test_invalid_json_encoding_nesting_and_constants(self):
        for data in (b'\xff', b'{} trailing', b'[[[[0]]]]', b'{"id":NaN}',
                     b'{"id":Infinity}', b'null', b'[]', b'\xef\xbb\xbf{}'):
            with self.assertRaises(ValueError): decode_profile(data, 'sensor')

    def test_unknown_missing_wrong_type_and_id(self):
        samples = [dict(document(), version=1), {'id': 'sensor'},
                   dict(document(), id='../bad'), dict(document(), id='different'),
                   dict(document(), read_ranges={})]
        for field, value in (('start', 0.0), ('count', True), ('safe_read', 1),
                             ('unknown', 1), ('max_count', None)):
            d = document(); d['read_ranges'][0][field] = value; samples.append(d)
        for d in samples:
            with self.assertRaises(ValueError): decode_profile(encode(d), 'sensor')

    def test_exact_file_size_boundary(self):
        raw = encode(document())
        self.assertEqual(decode_profile(raw + b' ' * (16384-len(raw)), 'sensor').id, 'sensor')
        with self.assertRaises(ValueError): decode_profile(raw + b' ' * (16385-len(raw)), 'sensor')

    def test_range_count_boundary(self):
        self.assertEqual(len(decode_profile(encode(document(count=64)), 'sensor').read_map.ranges), 64)
        with self.assertRaises(ValueError): decode_profile(encode(document(count=65)), 'sensor')

    def write(self, root, id='sensor', count=1):
        (Path(root)/(id+'.json')).write_bytes(encode(document(id, count)))

    def test_only_referenced_profiles_loaded_and_shared(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root)
            (Path(root)/'unused.json').write_bytes(b'not JSON')
            s = ProfileStore(); s.activate(root, {'a': 'sensor', 'b': 'sensor'}, maintenance=True)
            self.assertEqual(set(s.profiles), {'sensor'})
            self.assertIs(s.maps['a'], s.maps['b'])
            with self.assertRaises(TypeError): s.maps['a'] = None

    def test_failed_replacement_preserves_all_old_objects(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root); s = ProfileStore()
            s.activate(root, {'a': 'sensor'}, maintenance=True)
            old = (s.profiles, s.bindings, s.maps)
            (Path(root)/'bad.json').write_bytes(b'{}')
            with self.assertRaises(ValueError):
                s.activate(root, {'b': 'sensor', 'c': 'bad'}, maintenance=True)
            self.assertTrue(all(a is b for a, b in zip(old, (s.profiles, s.bindings, s.maps))))

    def test_cold_failure_has_no_configuration(self):
        with tempfile.TemporaryDirectory() as root:
            s = ProfileStore()
            with self.assertRaises(OSError): s.activate(root, {'a': 'missing'}, maintenance=True)
            self.assertFalse(s.maps)

    def test_activation_requires_idle_maintenance(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root); s = ProfileStore()
            for maintenance, active in ((False, 0), (True, 1), (True, -1), (True, False)):
                with self.assertRaises(ValueError):
                    s.activate(root, {'a': 'sensor'}, maintenance=maintenance, active_operations=active)
            self.assertFalse(s.maps)

    def test_traversal_symlink_and_special_file_rejected(self):
        import os
        with tempfile.TemporaryDirectory() as root:
            self.write(root)
            s = ProfileStore()
            with self.assertRaises(ValueError): s.activate(root, {'a': '../sensor'}, maintenance=True)
            (Path(root)/'link.json').symlink_to(Path(root)/'sensor.json')
            with self.assertRaises(OSError): s.activate(root, {'a': 'link'}, maintenance=True)
            os.mkfifo(str(Path(root)/'fifo.json'))
            with self.assertRaises(ValueError): s.activate(root, {'a': 'fifo'}, maintenance=True)
            self.assertFalse(s.maps)

    def test_device_profile_and_total_range_caps(self):
        with tempfile.TemporaryDirectory() as root:
            s = ProfileStore()
            for i in range(17): self.write(root, 'p'+str(i))
            s.activate(root, {str(i): 'p'+str(i) for i in range(16)}, maintenance=True)
            with self.assertRaises(ValueError):
                s.activate(root, {str(i): 'p'+str(i) for i in range(17)}, maintenance=True)
            s.activate(root, {str(i): 'p0' for i in range(32)}, maintenance=True)
            with self.assertRaises(ValueError):
                s.activate(root, {str(i): 'p0' for i in range(33)}, maintenance=True)
            for i in range(4): self.write(root, 'p'+str(i), 64)
            s.activate(root, {str(i): 'p'+str(i) for i in range(4)}, maintenance=True)
            with self.assertRaises(ValueError):
                s.activate(root, {str(i): 'p'+str(i) for i in range(5)}, maintenance=True)
            self.assertEqual(len(s.profiles), 4)

    def test_loader_maps_feed_scheduler(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root); store = ProfileStore()
            store.activate(root, {'d': 'sensor'}, maintenance=True)
            s = Scheduler([Transport('tcp', 'p')], read_maps=store.maps)
            self.assertEqual(s.enqueue('p', Request('a', 'd')), 'accepted')
            s.step(0); self.assertTrue(s.ports['p'].op.safe_read)


class Limits(unittest.TestCase):
    def setUp(self):
        self.helper = helpers.Groups()

    def test_logical_result_bytes_word_and_bit_boundaries(self):
        for fc, count, limit in ((3, 512, 125), (1, 8192, 2000)):
            s = self.helper.make([ReadRange(fc, 0, 20000, True, True, limit)])
            self.assertEqual(self.helper.put(s, 'ok', 0, count, fc), 'accepted')
            with self.assertRaises(ValueError): self.helper.put(s, 'bad', 0, count+1, fc)
            self.assertEqual(len(s.queues['p']), 1)

    def test_fragment_boundary_before_enqueue(self):
        s = self.helper.make([ReadRange(3, 0, 100, True, True, 1)])
        self.helper.put(s, 'ok', 0, 16)
        with self.assertRaises(ValueError): self.helper.put(s, 'bad', 0, 17)
        s.step(0)
        self.assertIsInstance(s.groups['p'].group.wires, WireSequence)
        self.assertEqual(len(s.groups['p'].group.wires), 16)
        self.assertEqual(len(s.groups['p'].buffer), 32)

    def test_group_consumer_cap(self):
        s = self.helper.make()
        for i in range(17): self.helper.put(s, str(i))
        s.step(0)
        self.assertEqual(len(s.groups['p'].group.entries), 16)
        self.assertEqual(len(s.queues['p']), 1)
        self.assertEqual(len(self.helper.exchange(s).results), 16)

    def test_pool_exact_limit_and_release(self):
        pool = AssemblyPool()
        for i in range(8): self.assertTrue(pool.acquire(i, 1024))
        self.assertEqual(pool.used, 8192)
        self.assertFalse(pool.acquire(8, 1))
        pool.release(0); self.assertTrue(pool.acquire(8, 1024))
        with self.assertRaises(ValueError): pool.acquire(9, 1025)

    def test_memory_wait_preserves_fifo_and_deadline(self):
        pool = AssemblyPool(2); pool.acquire('other', 2)
        s = Scheduler([Transport('tcp', 'p')], assembly_pool=pool,
                      read_maps={'d': ReadMap([ReadRange(3, 0, 10, True, True, 10)])})
        self.helper.put(s, 'a', expiry=5)
        p = s.step(0)
        self.assertIsNone(s.ports['p'].op); self.assertFalse(p.round_started)
        self.assertEqual(len(s.queues['p']), 1); self.assertEqual(s.next_wait(), 5)
        result = s.step(5).results[0]
        self.assertEqual(result.outcome, 'expired'); self.assertEqual(result.attempts, 0)
        self.assertEqual(pool.used, 2)
        pool.release('other'); self.helper.put(s, 'b'); s.step(5)
        self.assertEqual(pool.used, 2)
        self.helper.exchange(s, 6); self.assertEqual(pool.used, 0)

    def test_pool_released_on_error_cancel_and_timeout(self):
        for outcome in ('exception', 'cancel', 'timeout'):
            s = self.helper.make(); self.helper.put(s, 'a'); s.step(0)
            self.assertEqual(s.pool.used, 2)
            if outcome == 'exception':
                self.helper.exchange(s, exception=True)
            elif outcome == 'cancel':
                s.ports['p'].cancel(); s.step(0)
            else:
                s.step(10000)
            self.assertEqual(s.pool.used, 0)
            self.assertFalse(s.groups)

    def test_memory_blocked_rtu_does_not_create_phantom_round(self):
        pool = AssemblyPool(2); pool.acquire('other', 2)
        t = Transport('rtu', 'p'); t.confirm_sync('synthetic reset')
        s = Scheduler([t], assembly_pool=pool)
        s.enqueue('p', Request('a', 'd')); p = s.step(2)
        self.assertFalse(p.round_started); self.assertFalse(s.members)
        self.assertFalse(s.pending); self.assertEqual(s.round_number, 0)
        pool.release('other'); p = s.step(3)
        self.assertEqual(p.round_started, ('p',)); self.assertEqual(s.round_number, 1)

    def test_pool_held_across_fragments_then_released(self):
        s = self.helper.make([ReadRange(3, 0, 20, True, True, 2)])
        self.helper.put(s, 'a', 0, 5); s.step(0)
        self.assertEqual(s.pool.used, 10)
        self.helper.exchange(s); self.assertEqual(s.pool.used, 10)
        self.helper.exchange(s, 2); self.assertEqual(s.pool.used, 10)
        result = self.helper.exchange(s, 3).results[0]
        self.assertEqual(len(result.data), 10); self.assertEqual(s.pool.used, 0)


if __name__ == '__main__':
    unittest.main()
