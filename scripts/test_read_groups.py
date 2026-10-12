"""Safe-map and grouped wire regression tests; no real I/O."""
import unittest
from dataclasses import FrozenInstanceError
from transport_states import Transport, Request, tcp_frame
from transport_scheduler import Scheduler, Event
from read_groups import ReadRange, ReadMap


class Groups(unittest.TestCase):
    def make(self, ranges=None, limit=32):
        ranges = ranges or [ReadRange(3, 0, 100, True, True, 20)]
        return Scheduler([Transport('tcp', 'p')], queue_limit=limit,
                         read_maps={'d': ReadMap(ranges)})

    def put(self, s, id, addr=0, count=1, fc=3, **kwargs):
        return s.enqueue('p', Request(id, 'd', function=fc, address=addr, count=count), **kwargs)

    def exchange(self, s, now=1, exception=False):
        t = s.ports['p']
        for kind in ('setup', 'tx', 'tx_complete'):
            s.step(now, {'p': Event(kind, len(t.wire) if kind == 'tx' else None, t.generation)})
        req = t.op
        if exception:
            pdu = bytes([req.function | 128, 2])
        elif req.function == 6:
            pdu = req.pdu()
        elif req.function <= 2:
            data = bytearray((req.count + 7) // 8)
            for i in range(req.count):
                data[i // 8] |= ((req.address + i) % 3 == 0) << (i % 8)
            pdu = bytes([req.function, len(data)]) + data
        else:
            data = b''.join(i.to_bytes(2, 'big') for i in range(req.address, req.address + req.count))
            pdu = bytes([req.function, len(data)]) + data
        return s.step(now, {'p': Event('rx', tcp_frame(t.tid, req.unit, pdu), t.generation)})

    def test_adjacent_overlap_duplicate_fanout(self):
        s = self.make()
        self.put(s, 'a', 2, 4); self.put(s, 'b', 4, 4); self.put(s, 'c', 2, 4)
        s.step(0)
        self.assertEqual((s.ports['p'].op.address, s.ports['p'].op.count), (2, 6))
        out = self.exchange(s).results
        self.assertEqual([r.operation_id for r in out], ['a', 'b', 'c'])
        self.assertEqual(out[0].data, bytes.fromhex('0002000300040005'))
        self.assertEqual(out[1].data, bytes.fromhex('0004000500060007'))
        self.assertEqual(out[0].data, out[2].data)
        self.assertEqual({r.end for r in out}, {1})

    def test_gap_default_and_explicit(self):
        for gap, expected in ((0, 2), (1, 2), (2, 6)):
            s = self.make([ReadRange(3, 0, 20, True, True, 20, gap)])
            self.put(s, 'a', 0, 2); self.put(s, 'b', 4, 2); s.step(0)
            self.assertEqual(s.ports['p'].op.count, expected)

    def test_range_boundary_not_crossed_even_when_adjacent(self):
        s = self.make([ReadRange(3, 0, 2, True, True, 2), ReadRange(3, 2, 2, True, True, 2)])
        self.put(s, 'a', 0, 2); self.put(s, 'b', 2, 2); s.step(0)
        self.assertEqual(s.ports['p'].op.count, 2)
        self.assertEqual(len(s.queues['p']), 1)
        with self.assertRaises(ValueError): self.put(s, 'bad', 1, 2)

    def test_holes_and_unknown_map_rejected(self):
        s = self.make()
        with self.assertRaises(ValueError): self.put(s, 'bad', 99, 2)
        with self.assertRaises(ValueError): s.enqueue('p', Request('x', 'unknown', unit=2))
        self.assertFalse(s.queues['p'])

    def test_client_cannot_override_safety(self):
        s = self.make([ReadRange(3, 0, 10, False, False, 10)])
        s.enqueue('p', Request('x', 'd', safe_read=True)); self.put(s, 'b', 1)
        s.step(0)
        self.assertFalse(s.ports['p'].op.safe_read)
        self.assertEqual(s.ports['p'].op.count, 1)

    def test_nonmergeable_safe_range(self):
        s = self.make([ReadRange(3, 0, 10, True, False, 10)])
        self.put(s, 'a'); self.put(s, 'b', 1); s.step(0)
        self.assertTrue(s.ports['p'].op.safe_read)
        self.assertEqual(len(s.queues['p']), 1)

    def test_write_and_readback_are_barriers(self):
        for barrier in ('write', 'readback'):
            s = self.make()
            self.put(s, 'a')
            self.put(s, 'barrier', 1, fc=6 if barrier == 'write' else 3,
                     readback=barrier == 'readback')
            self.put(s, 'b', 2); s.step(0)
            self.assertEqual(s.ports['p'].op.count, 1)
            self.exchange(s)
            self.assertEqual(s.ports['p'].op.operation_id, 'barrier')
            self.assertEqual(s.ports['p'].op.count, 1)
            self.exchange(s, 2)
            self.assertEqual(s.ports['p'].op.operation_id, 'b')

    def test_writes_are_not_deduplicated(self):
        s = self.make()
        self.put(s, 'on', 7, 1, fc=6); self.put(s, 'off', 7, 0, fc=6)
        s.step(0); self.assertEqual(s.ports['p'].op.count, 1)
        self.exchange(s); self.assertEqual(s.ports['p'].op.count, 0)

    def test_function_is_a_fifo_barrier(self):
        s = self.make([ReadRange(3, 0, 10, True, True, 10), ReadRange(4, 0, 10, True, True, 10)])
        self.put(s, 'a'); self.put(s, 'barrier', fc=4); self.put(s, 'b', 1)
        s.step(0); self.assertEqual(s.ports['p'].op.count, 1)
        self.assertEqual(len(s.queues['p']), 2)

    def test_minimum_deadline_and_original_start(self):
        s = self.make(); self.put(s, 'a', expiry=500)
        s.now = 10; self.put(s, 'b', 1, expiry=100)
        s.step(10); self.assertEqual(s.ports['p'].dop, 100)
        out = self.exchange(s, 20).results
        self.assertEqual([r.start for r in out], [0, 10])

    def test_consumer_quota_not_bypassed_by_grouping(self):
        s = self.make(limit=3)
        for i in range(3): self.put(s, str(i), i)
        s.step(0)
        self.assertEqual(self.put(s, 'four', 3), 'accepted')
        self.assertEqual(self.put(s, 'five', 4), 'busy')
        with self.assertRaises(ValueError): self.put(s, '1', 1)

    def test_device_limit_splits_and_assembles(self):
        s = self.make([ReadRange(3, 0, 20, True, True, 2)])
        self.put(s, 'a', 0, 5); s.step(0)
        self.assertEqual(s.ports['p'].op.count, 2)
        self.assertFalse(self.exchange(s).results)
        self.assertFalse(s.ports['p'].valid)
        self.assertIsNone(s.ports['p'].last_success)
        self.assertFalse(self.exchange(s, 2).results)
        self.assertEqual(s.ports['p'].op.count, 1)
        result = self.exchange(s, 3).results[0]
        self.assertEqual(result.data, bytes.fromhex('00000001000200030004'))
        self.assertEqual(result.attempts, 3)

    def test_split_failure_has_no_partial_payload_or_exception_retry(self):
        s = self.make([ReadRange(3, 0, 20, True, True, 2)])
        self.put(s, 'a', 0, 5); s.step(0); self.exchange(s)
        result = self.exchange(s, 2, exception=True).results[0]
        self.assertEqual(result.outcome, 'modbus_exception')
        self.assertEqual(result.data, b'')
        self.assertFalse(s.groups); self.assertIsNone(s.ports['p'].op)
        self.assertIsNone(s.ports['p'].last_success)

    def test_bit_offsets_and_split_padding(self):
        s = self.make([ReadRange(1, 0, 100, True, True, 20)])
        self.put(s, 'a', 1, 9, fc=1); self.put(s, 'b', 3, 7, fc=1); s.step(0)
        out = self.exchange(s).results
        self.assertEqual(out[0].data, bytes([0b00100100, 1]))
        self.assertEqual(out[1].data, bytes([0b01001001]))
        s = self.make([ReadRange(2, 0, 100, True, True, 5)])
        self.put(s, 'split', 0, 9, fc=2); s.step(0); self.exchange(s)
        self.assertEqual(self.exchange(s, 2).results[0].data, bytes([0b01001001, 0]))

    def test_split_expiry_does_not_extend_original_deadline(self):
        s = self.make([ReadRange(3, 0, 20, True, True, 2)])
        self.put(s, 'a', 0, 5, expiry=3); s.step(0); self.exchange(s, 1)
        result = s.step(3).results[0]
        self.assertEqual(result.outcome, 'timeout')
        self.assertEqual(result.data, b'')
        self.assertEqual(result.start, 0)

    def test_unsafe_split_is_rejected_before_queue(self):
        s = self.make([ReadRange(3, 0, 20, False, False, 2)])
        with self.assertRaises(ValueError): self.put(s, 'a', 0, 3)
        self.assertFalse(s.queues['p'])

    def test_group_limit_does_not_skip_fifo_head(self):
        s = self.make([ReadRange(3, 0, 20, True, True, 3)])
        self.put(s, 'a', 0, 2); self.put(s, 'b', 2, 2); self.put(s, 'c', 0, 1)
        s.step(0)
        self.assertEqual(s.ports['p'].op.count, 2)
        self.assertEqual([e.request.operation_id for e in s.queues['p']], ['b', 'c'])

    def test_rtu_split_holds_round_but_expires_during_gap(self):
        from transport_states import rtu_frame
        t = Transport('rtu', 'p', baud=9600)
        t.confirm_sync('synthetic reset')
        s = Scheduler([t], read_maps={'d': ReadMap([ReadRange(3, 0, 10, True, True, 1)])})
        self.put(s, 'a', 0, 2, expiry=6); s.step(4)
        for event in (Event('setup'), Event('tx', 8), Event('tx_complete')):
            s.step(4, {'p': event})
        out = s.step(5, {'p': Event('rx', rtu_frame(bytes.fromhex('0103020001')))})
        self.assertFalse(out.results); self.assertEqual(s.pending, {'p'})
        self.assertIsNone(t.op)
        out = s.step(6)
        self.assertEqual(out.results[0].outcome, 'timeout')
        self.assertFalse(s.pending)
        self.assertIsNone(t.last_success)

    def test_protocol_limit_splits_logical_read(self):
        s = self.make([ReadRange(3, 0, 200, True, True, 125)])
        self.put(s, 'large', 0, 126); s.step(0)
        self.assertEqual(s.ports['p'].op.count, 125)
        self.assertFalse(self.exchange(s).results)
        self.assertEqual(s.ports['p'].op.count, 1)
        result = self.exchange(s, 2).results[0]
        self.assertEqual(len(result.data), 252)
        self.assertEqual(result.data[-2:], bytes.fromhex('007d'))

    def test_map_validation_and_immutability(self):
        for kwargs in ({'start': -1}, {'count': 0}, {'start': 65535, 'count': 2},
                       {'max_count': 126}, {'max_gap': -1}, {'safe_read': 1},
                       {'safe_read': False, 'mergeable': True}):
            args = dict(function=3, start=0, count=10, safe_read=True, mergeable=True)
            args.update(kwargs)
            with self.assertRaises(ValueError): ReadRange(**args)
        with self.assertRaises(ValueError): ReadMap([ReadRange(3, 0, 5), ReadRange(3, 4, 5)])
        with self.assertRaises(TypeError): ReadRange(3, 0, 10, unknown=True)
        m = ReadMap([ReadRange(3, 0, 5)])
        with self.assertRaises(FrozenInstanceError): m.ranges = ()


if __name__ == '__main__':
    unittest.main()
