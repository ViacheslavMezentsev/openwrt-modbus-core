"""Composition tests with controlled clocks and actual RTU/TCP frame bytes."""
import unittest
from transport_states import Transport, Request, rtu_frame, tcp_frame
from transport_scheduler import Scheduler, Event


class Rounds(unittest.TestCase):
    def scheduler(self, kinds=('rtu', 'rtu', 'rtu'), **options):
        ports = [Transport(kind, str(i), request_timeout=1000, **options)
                 for i, kind in enumerate(kinds)]
        for t in ports:
            if t.kind == 'rtu':
                t.confirm_sync('synthetic bench reset')
        return Scheduler(ports)

    def enqueue(self, s, port, op, **kwargs):
        return s.enqueue(port, Request(op, 'd' + port, safe_read=True), **kwargs)

    def event(self, s, port, kind, data=None):
        return Event(kind, data, s.ports[port].generation)

    def send(self, s, now):
        for kind in ('setup', 'tx', 'tx_complete'):
            events = {}
            expected = {'setup': 'setup', 'tx': 'send', 'tx_complete': 'tx_completion'}[kind]
            for name, t in s.ports.items():
                if t.state == expected:
                    events[name] = self.event(s, name, kind, len(t.wire) if kind == 'tx' else None)
            s.step(now, events)

    def frame(self, s, port):
        t = s.ports[port]
        pdu = bytes([3, 2, 0, 17])
        return (rtu_frame(bytes([t.op.unit]) + pdu) if t.kind == 'rtu' else
                tcp_frame(t.tid, t.op.unit, pdu))

    def reply(self, s, port, now):
        return s.step(now, {port: self.event(s, port, 'rx', self.frame(s, port))})

    def test_10_20_500_round_and_early_results(self):
        s = self.scheduler()
        for port in s.ports:
            self.enqueue(s, port, 'first'); self.enqueue(s, port, 'second')
        p = s.step(2); self.assertEqual(set(p.round_started), set(s.ports))
        self.send(s, 2)
        self.assertEqual(self.reply(s, '0', 12).results[0].end, 12)
        self.assertEqual(self.reply(s, '1', 22).results[0].end, 22)
        self.assertEqual(s.round_number, 1)
        self.assertEqual(s.ports['0'].state, 'idle')
        p = self.reply(s, '2', 502)
        self.assertEqual(p.results[0].outcome, 'ok')
        self.assertEqual(s.round_number, 2)
        self.assertTrue({'0', '1'} <= set(p.round_started))

    def test_new_port_waits_for_next_round(self):
        s = self.scheduler(('rtu', 'rtu'))
        self.enqueue(s, '0', 'a'); s.step(2); self.send(s, 2)
        self.enqueue(s, '1', 'b'); s.step(10)
        self.assertIsNone(s.ports['1'].op)
        p = self.reply(s, '0', 20)
        self.assertEqual(p.round_started, ('1',))

    def test_tcp_and_ipc_continue_behind_rtu_barrier(self):
        s = self.scheduler(('rtu', 'tcp'))
        for p in s.ports: self.enqueue(s, p, 'a')
        self.enqueue(s, '1', 'b'); s.step(2); self.send(s, 2)
        self.assertTrue(s.post_ipc(20))
        p = self.reply(s, '1', 12)
        self.assertEqual(p.ipc_serviced, 8)
        self.assertEqual(s.ports['1'].op.operation_id, 'b')
        self.assertEqual(s.pending, {'0'})
        self.send(s, 12)
        self.assertEqual(self.reply(s, '1', 20).results[0].operation_id, 'b')
        self.assertEqual(s.round_number, 1)
        self.assertEqual(s.ipc_pending, 0)

    def test_retries_stay_inside_round(self):
        s = self.scheduler(('rtu', 'rtu'), policy='bounded', late_bound=1200,
                           timing_profile='synthetic', retries=1)
        for p in s.ports: self.enqueue(s, p, 'a')
        self.enqueue(s, '0', 'b'); s.step(2); self.send(s, 2)
        self.reply(s, '0', 12)
        s.step(1002); self.assertEqual(s.ports['1'].state, 'quarantine')
        self.assertEqual(s.round_number, 1)
        s.step(1203); self.send(s, 1203)
        p = self.reply(s, '1', 1210)
        self.assertEqual(p.results[0].attempts, 2)
        self.assertEqual(s.round_number, 2)

    def test_queue_wait_is_in_deadline_and_result_start(self):
        s = self.scheduler(('rtu', 'rtu'))
        for p in s.ports: self.enqueue(s, p, 'a')
        self.enqueue(s, '0', 'b', expiry=900)
        s.step(2); self.send(s, 2); self.reply(s, '0', 12)
        self.reply(s, '1', 800)
        t = s.ports['0']
        self.assertEqual((t.start, t.dop), (0, 900))
        self.send(s, 800)
        p = s.step(900)
        self.assertEqual([(r.operation_id, r.outcome) for r in p.results], [('b', 'timeout')])
        self.assertEqual(p.results[0].start, 0)

    def test_expired_non_head_is_pruned_before_admission(self):
        s = self.scheduler(('tcp',))
        self.enqueue(s, '0', 'head', expiry=1000)
        self.enqueue(s, '0', 'tail', expiry=20)
        p = s.step(20)
        self.assertEqual(p.results[0].operation_id, 'tail')
        self.assertEqual(p.results[0].attempts, 0)
        self.assertEqual(s.ports['0'].op.operation_id, 'head')

    def test_queue_full_and_one_pending_periodic(self):
        s = Scheduler([Transport('tcp', '0')], queue_limit=1)
        self.assertEqual(self.enqueue(s, '0', 'a', periodic='poll'), 'accepted')
        original_expiry = s.queues['0'][0].expiry
        self.assertEqual(self.enqueue(s, '0', 'b', periodic='poll'), 'coalesced')
        self.assertEqual(s.queues['0'][0].expiry, original_expiry)
        self.assertEqual(self.enqueue(s, '0', 'c'), 'busy')
        s.step(0)
        self.assertEqual(self.enqueue(s, '0', 'next', periodic='poll'), 'accepted')
        self.assertEqual(self.enqueue(s, '0', 'another', periodic='poll'), 'coalesced')
        self.assertEqual(len(s.queues['0']), 1)

    def test_changed_pending_plan_is_not_silently_coalesced(self):
        s = self.scheduler(('tcp',))
        self.enqueue(s, '0', 'a', periodic='poll')
        with self.assertRaises(ValueError):
            s.enqueue('0', Request('b', 'd0', address=5), periodic='poll')
        self.assertEqual(s.queues['0'][0].request.address, 0)

    def test_desynchronized_port_excluded_and_queue_expires(self):
        s = Scheduler([Transport('rtu', '0'), Transport('tcp', '1')])
        self.enqueue(s, '0', 'a', expiry=20); self.enqueue(s, '1', 'b')
        s.step(0); self.send(s, 0)
        self.assertIsNone(s.ports['0'].op)
        self.assertEqual(self.reply(s, '1', 10).results[0].outcome, 'ok')
        p = s.step(20)
        self.assertEqual(p.results[0].outcome, 'expired')
        self.assertEqual(s.ports['0'].state, 'desynchronized')

    def test_quarantine_after_result_does_not_hold_barrier(self):
        s = self.scheduler(('rtu', 'rtu'), operation_timeout=1100,
                           policy='bounded', late_bound=2000, timing_profile='synthetic')
        for port in s.ports: self.enqueue(s, port, 'a')
        s.step(2); self.send(s, 2); self.reply(s, '0', 10)
        s.step(500); self.enqueue(s, '0', 'b')
        p = s.step(1002)
        self.assertEqual(p.results[0].outcome, 'timeout')
        self.assertEqual(s.ports['1'].state, 'quarantine')
        self.assertEqual(p.round_started, ('0',))

    def test_endpoint_order_rotates_and_io_budget_is_bounded(self):
        s = self.scheduler(('rtu', 'tcp'))
        for p in s.ports: self.enqueue(s, p, 'a')
        first = s.step(2); second = s.step(2)
        self.assertEqual(first.order, tuple(reversed(second.order)))
        self.send(s, 2)
        p = s.step(10, {n: self.event(s, n, 'rx', b'x' * 512) for n in s.ports})
        self.assertEqual(p.io_bytes, {'0': 512, '1': 512})
        self.assertTrue(all(v <= 8 for v in p.transitions.values()))
        with self.assertRaises(ValueError):
            s.step(11, {'0': Event('rx', b'x' * 513)})
        self.assertEqual(s.now, 10)

    def test_fifo_write_order_without_grouping(self):
        s = self.scheduler(('tcp',))
        s.enqueue('0', Request('write', 'd0', function=6, count=1))
        self.enqueue(s, '0', 'readback')
        s.step(0); self.send(s, 0)
        t = s.ports['0']
        p = s.step(10, {'0': self.event(s, '0', 'rx', tcp_frame(t.tid, 1, t.op.pdu()))})
        self.assertEqual(p.results[0].write_outcome, 'confirmed')
        self.assertEqual(t.op.operation_id, 'readback')

    def test_idle_wait_and_expiry_wakeup(self):
        s = self.scheduler(('tcp',)); self.assertIsNone(s.next_wait())
        self.enqueue(s, '0', 'a', expiry=9)
        self.assertEqual(s.next_wait(), 0)
        s.step(0); self.assertEqual(s.next_wait(), 9)
        p = s.step(9); self.assertEqual(p.results[0].outcome, 'expired')
        self.assertIsNone(s.next_wait())
        s.post_ipc(); self.assertEqual(s.next_wait(), 0)

    def test_backoff_endpoint_waits_without_joining_round(self):
        s = self.scheduler(('tcp',))
        self.enqueue(s, '0', 'a'); self.enqueue(s, '0', 'b')
        s.step(0); self.send(s, 0)
        t = s.ports['0']
        p = s.step(10, {'0': self.event(s, '0', 'error')})
        self.assertEqual(p.results[0].outcome, 'io_error')
        self.assertIsNone(t.op)
        s.step(1009); self.assertIsNone(t.op)
        s.step(1010); self.assertEqual(t.op.operation_id, 'b')

    def test_duplicate_and_limits_rejected_without_queue_changes(self):
        s = self.scheduler(('tcp',))
        self.enqueue(s, '0', 'a')
        with self.assertRaises(ValueError): self.enqueue(s, '0', 'a')
        with self.assertRaises(ValueError): s.enqueue('0', Request('b', 'alias'))
        with self.assertRaises(ValueError): s.enqueue('0', Request('b', 'd0', unit=2))
        self.assertEqual(len(s.queues['0']), 1)
        self.assertTrue(s.post_ipc(128)); self.assertFalse(s.post_ipc())
        with self.assertRaises(ValueError): Scheduler([Transport('rtu', str(i)) for i in range(4)])


if __name__ == '__main__':
    unittest.main()
