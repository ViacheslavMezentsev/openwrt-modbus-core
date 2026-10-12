"""Deterministic contract tests. No hardware, sockets, sleeps or real clocks."""
import struct
import unittest
from transport_states import Transport, Request, crc16, rtu_frame, tcp_frame, silence_ms


class States(unittest.TestCase):
    def ready(self, kind='tcp', request=None, **options):
        t = Transport(kind, **options)
        if kind == 'rtu':
            t.confirm_sync('synthetic reset completed; no pending response')
            t.tick(t.gap)
        self.assertTrue(t.admit(request or Request('op', 'board', safe_read=True)))
        self.assertTrue(t.begin())
        t.setup_done(t.generation)
        return t

    def send(self, t):
        t.tx(len(t.wire), t.generation)
        t.tx_complete(t.generation)
        self.assertEqual(t.state, 'receive')

    def response(self, t, pdu=b'\x03\x02\x12\x34'):
        return (tcp_frame(t.tid, t.op.unit, pdu) if t.kind == 'tcp' else
                rtu_frame(bytes([t.op.unit]) + pdu))

    def result(self, t, outcome):
        results = t.drain_results()
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].outcome, outcome)
        return results[0]

    def test_crc_known_vector(self):
        # Known FC03 request: unit 1, address 0, quantity 10.
        frame = bytes.fromhex('01 03 00 00 00 0a c5 cd')
        self.assertEqual(rtu_frame(frame[:-2]), frame)
        self.assertEqual(crc16(frame), 0)

    def test_tcp_every_split(self):
        for split in range(1, 11):
            with self.subTest(split=split):
                t = self.ready(); self.send(t)
                response = self.response(t)
                t.receive(response[:split], t.generation)
                self.assertFalse(t.results)
                t.tick(499)
                t.receive(response[split:], t.generation)
                self.assertEqual(self.result(t, 'ok').data, b'\x12\x34')

    def test_rtu_every_split(self):
        for split in range(1, 7):
            t = self.ready('rtu'); self.send(t)
            response = self.response(t)
            t.receive(response[:split]); self.assertFalse(t.results)
            t.receive(response[split:]); self.result(t, 'ok')

    def test_exact_deadline_timeout_before_buffered_response(self):
        for kind in ('rtu', 'tcp'):
            t = self.ready(kind); self.send(t)
            frame, gen, deadline = self.response(t), t.generation, t.da
            t.tick(deadline)
            t.receive(frame, gen)
            self.result(t, 'timeout')
            self.assertFalse(t.valid)

    def test_fragments_do_not_extend_deadline(self):
        t = self.ready(); self.send(t)
        frame = self.response(t)
        t.tick(499); t.receive(frame[:8], t.generation)
        t.tick(500); t.receive(frame[8:], t.generation)
        self.result(t, 'timeout')

    def test_expiry_in_queue_never_sends(self):
        t = Transport('tcp')
        t.admit(Request('q', 'd'), expiry=50)
        t.tick(50); self.assertFalse(t.begin())
        self.assertEqual(self.result(t, 'expired').attempts, 0)
        self.assertEqual(t.wire, b'')

    def test_setup_timeout_retries_are_counted(self):
        t = Transport('tcp', retries=3, setup_timeout=100)
        t.admit(Request('q', 'd', safe_read=True)); t.begin()
        for i in range(4):
            t.tick(t.setup_deadline)
            if i < 3:
                self.assertEqual(t.state, 'retry')
                t.tick(t.retry_at)
        result = self.result(t, 'timeout')
        self.assertEqual((result.attempts, result.sent_attempts), (4, 0))

    def test_no_retry_by_default(self):
        t = self.ready(); self.send(t); t.tick(500)
        self.assertEqual(self.result(t, 'timeout').attempts, 1)

    def test_unsafe_reads_never_retry(self):
        t = self.ready(request=Request('op', 'd'), retries=3)
        self.send(t); t.io_error(t.generation)
        self.assertEqual(self.result(t, 'io_error').attempts, 1)

    def test_exceptions_never_retry(self):
        for kind in ('rtu', 'tcp'):
            t = self.ready(kind, retries=3); self.send(t)
            t.receive(self.response(t, b'\x83\x06'), t.generation)
            self.assertEqual(self.result(t, 'modbus_exception').exception_code, 6)

    def test_partial_tx_and_eagain_share_deadline(self):
        t = self.ready(); t.tx(0, t.generation)
        deadline = t.da
        t.tick(100); t.tx(3, t.generation)
        t.tick(499); t.tx(len(t.wire)-3, t.generation)
        t.tx_complete(t.generation)
        self.assertEqual(t.da, deadline)
        t.tick(500); self.result(t, 'timeout')

    def test_partial_rtu_tx_cannot_use_bounded_recovery(self):
        t = self.ready('rtu', policy='bounded', late_bound=800,
                       timing_profile='synthetic guaranteed bound', retries=3)
        t.tx(1); t.io_error()
        self.assertEqual(t.state, 'desynchronized')
        self.result(t, 'io_error')

    def test_tx_completion_wait_is_inside_deadline(self):
        t = self.ready('rtu'); t.tx(len(t.wire))
        t.tick(t.da); t.tx_complete()
        self.result(t, 'timeout')
        self.assertEqual(t.state, 'desynchronized')

    def test_manual_late_reply_cannot_complete_different_address(self):
        t = self.ready('rtu'); self.send(t)
        old = self.response(t)
        t.tick(t.da); self.result(t, 'timeout')
        self.assertTrue(t.admit(Request('next', 'board', address=100)))
        self.assertFalse(t.begin())
        t.receive(old); self.assertFalse(t.results)
        self.assertEqual(t.state, 'desynchronized')
        t.cancel(); self.result(t, 'cancelled')

    def test_unknown_start_and_new_instance_require_confirmation(self):
        for _ in range(2):
            t = Transport('rtu')
            t.admit(Request('a', 'b'))
            self.assertFalse(t.begin())
            t.tick(10000); self.result(t, 'expired')
            self.assertEqual(t.state, 'desynchronized')
            t.confirm_sync('external reset evidence')
            self.assertEqual(t.state, 'idle')

    def test_bounded_quarantine_retry_and_success(self):
        t = self.ready('rtu', policy='bounded', late_bound=800,
                       timing_profile='synthetic guarantee', retries=1)
        self.send(t); old = self.response(t); bound = t.last_write + 800
        t.tick(t.da); self.assertEqual(t.state, 'quarantine')
        t.tick(bound-1); t.receive(old)
        self.assertFalse(t.valid); self.assertFalse(t.results)
        t.tick(bound); self.assertEqual(t.state, 'quarantine')
        t.tick(bound+1); self.assertEqual(t.state, 'setup')
        t.setup_done(); self.send(t)
        t.receive(self.response(t))
        self.assertEqual(self.result(t, 'ok').attempts, 2)

    def test_beyond_bound_desynchronizes(self):
        t = self.ready('rtu', policy='bounded', late_bound=800,
                       timing_profile='synthetic guarantee', retries=1)
        self.send(t); frame = self.response(t); bound = t.last_write + 800
        t.tick(t.da); t.tick(bound); t.receive(frame)
        t.tick(bound+1); t.receive(b'x')
        self.assertEqual(t.state, 'desynchronized')
        self.result(t, 'desynchronized')

    def test_operation_expiry_releases_result_but_not_quarantine(self):
        t = self.ready('rtu', operation_timeout=600, policy='bounded',
                       late_bound=800, timing_profile='synthetic', retries=3)
        self.send(t); t.tick(t.da); t.tick(t.dop)
        self.result(t, 'timeout'); self.assertEqual(t.state, 'quarantine')
        self.assertFalse(t.admit(Request('b', 'd')))
        t.tick(803); self.assertEqual(t.state, 'idle')

    def test_crc_failure_invalidates_without_losing_last_success(self):
        t = self.ready('rtu'); self.send(t); t.receive(self.response(t))
        self.result(t, 'ok'); last = t.last_success
        t.tick(t.ready_at); t.admit(Request('b', 'board')); t.begin(); t.setup_done()
        self.send(t); frame = self.response(t)
        t.receive(frame[:-1] + bytes([frame[-1] ^ 1]))
        self.result(t, 'protocol_error')
        self.assertFalse(t.valid); self.assertEqual(t.last_success, last)
        self.assertEqual(t.state, 'desynchronized')

    def test_tcp_old_generation_cannot_complete_retry(self):
        t = self.ready(retries=1); self.send(t)
        frame, old = self.response(t), t.generation
        t.tick(t.da)
        t.receive(frame, old); t.io_error(old); t.setup_done(old)
        self.assertEqual(t.state, 'retry')
        t.tick(t.retry_at); t.setup_done(t.generation); self.send(t)
        t.receive(frame, old); self.assertFalse(t.results)
        t.receive(self.response(t), t.generation)
        self.assertEqual(self.result(t, 'ok').attempts, 2)

    def test_tcp_header_faults_terminal(self):
        for field, value in ((0, 9), (1, 1), (2, 1), (2, 255), (3, 2)):
            t = self.ready(retries=3); self.send(t)
            fields = [t.tid, 0, 5, 1]; fields[field] = value
            t.receive(struct.pack('>HHHB', *fields), t.generation)
            self.result(t, 'protocol_error')
            self.assertFalse(t.connected)

    def test_wrong_fc_and_payload_length(self):
        for pdu in (b'\x04\x02\x00\x00', b'\x03\x01\x00', b'\x83\x00'):
            t = self.ready(); self.send(t)
            t.receive(self.response(t, pdu), t.generation)
            self.result(t, 'protocol_error')

    def test_coalesced_extra_frame_closes_without_second_result(self):
        t = self.ready(); self.send(t); frame = self.response(t)
        t.receive(frame + frame, t.generation)
        self.result(t, 'ok'); self.assertFalse(t.connected)
        self.assertFalse(t.drain_results())

    def test_transaction_id_wrap_changes_connection(self):
        t = self.ready(); self.send(t); t.receive(self.response(t), t.generation)
        self.result(t, 'ok'); old = t.generation; t.next_tid = 65535
        for name, expected in (('last', 65535), ('new', 0)):
            t.admit(Request(name, 'd')); t.begin(); t.setup_done(t.generation)
            self.assertEqual(t.tid, expected)
            self.send(t); t.receive(self.response(t), t.generation); self.result(t, 'ok')
        self.assertGreater(t.generation, old)

    def test_writes_unknown_confirmed_and_not_sent(self):
        for kind in ('rtu', 'tcp'):
            for sent in (False, True):
                t = self.ready(kind, request=Request('w', 'd', function=6, count=1), retries=3)
                if sent: t.tx(1, t.generation)
                t.cancel()
                r = self.result(t, 'cancelled')
                self.assertEqual(r.write_outcome, 'unknown' if sent else 'not_sent')
                self.assertEqual(r.attempts, 1)
            t = self.ready(kind, request=Request('w', 'd', function=6, count=1))
            self.send(t); t.receive(self.response(t, t.op.pdu()), t.generation)
            self.assertEqual(self.result(t, 'ok').write_outcome, 'confirmed')

    def test_eof_retries_safe_read(self):
        t = self.ready(retries=1); self.send(t)
        t.receive(b'', t.generation)
        self.assertEqual(t.state, 'retry'); self.assertFalse(t.connected)

    def test_bounded_input_and_rx_capacity(self):
        t = self.ready(); self.send(t)
        with self.assertRaises(ValueError): t.receive(b'x' * 513, t.generation)
        # A declared maximum-sized ADU, incomplete first chunk, then excess bytes.
        header = struct.pack('>HHHB', t.tid, 0, 254, 1)
        t.receive(header + b'x' * 200, t.generation)
        t.receive(b'x' * 314, t.generation)
        self.result(t, 'protocol_error'); self.assertLessEqual(len(t.rx), 520)
        t = self.ready('rtu'); self.send(t)
        t.receive(b'x' * 257); self.result(t, 'protocol_error')

    def test_largest_read_frames(self):
        for kind in ('rtu', 'tcp'):
            for fc, count, size in ((1, 2000, 250), (2, 9, 2), (3, 125, 250), (4, 125, 250)):
                t = self.ready(kind, request=Request('r', 'd', function=fc, count=count))
                self.send(t)
                t.receive(self.response(t, bytes([fc, size]) + bytes(size)), t.generation)
                self.assertEqual(len(self.result(t, 'ok').data), size)

    def test_two_ports_independent_of_desync(self):
        bad = self.ready('rtu'); good = self.ready('rtu')
        self.send(bad); self.send(good); bad.tick(bad.da)
        good.receive(self.response(good)); self.result(good, 'ok')
        self.result(bad, 'timeout')

    def test_monotonic_time_and_result_backpressure(self):
        t = self.ready(); self.send(t); t.tick(10)
        with self.assertRaises(ValueError): t.tick(9)
        t.receive(self.response(t), t.generation)
        self.assertFalse(t.admit(Request('b', 'd')))
        t.cancel(); t.tick(10000)
        self.result(t, 'ok'); self.assertTrue(t.admit(Request('b', 'd')))

    def test_full_write_without_tx_completion_still_desynchronizes(self):
        t = self.ready('rtu', policy='bounded', late_bound=800,
                       timing_profile='synthetic', retries=3)
        t.tx(len(t.wire)); t.tick(t.da)
        self.result(t, 'timeout'); self.assertEqual(t.state, 'desynchronized')

    def test_quarantine_accepts_discard_at_exact_bound(self):
        t = self.ready('rtu', policy='bounded', late_bound=800,
                       timing_profile='synthetic', retries=1)
        self.send(t); frame = self.response(t); bound = t.last_write + 800
        t.tick(t.da); t.tick(bound); t.receive(frame)
        self.assertEqual(t.state, 'quarantine'); self.assertFalse(t.results)
        t.tick(bound + t.gap); self.assertEqual(t.state, 'setup')

    def test_tcp_callback_that_expires_deadline_is_stale(self):
        t = self.ready(retries=1); self.send(t)
        frame, gen = self.response(t), t.generation
        # Advance the injected clock without servicing: receive services timers first.
        t.now = t.da
        t.receive(frame, gen)
        self.assertEqual(t.state, 'retry'); self.assertFalse(t.results)

    def test_retry_invalidates_previous_valid_immediately(self):
        t = self.ready(retries=1); self.send(t)
        t.receive(self.response(t), t.generation); self.result(t, 'ok')
        last = t.last_success
        t.admit(Request('next', 'board', safe_read=True)); t.begin()
        t.setup_done(t.generation); self.send(t); t.io_error(t.generation)
        self.assertEqual(t.state, 'retry')
        self.assertFalse(t.valid); self.assertEqual(t.last_success, last)

    def test_logical_devices_do_not_share_freshness(self):
        t = self.ready(request=Request('a', 'first')); self.send(t)
        t.receive(self.response(t), t.generation); self.result(t, 'ok')
        t.admit(Request('b', 'second', unit=2))
        self.assertFalse(t.valid); self.assertIsNone(t.last_success)
        t.cancel(); self.result(t, 'cancelled')
        self.assertTrue(t.samples['first']['valid'])
        self.assertFalse(t.samples['second']['valid'])

    def test_logical_device_observations_are_bounded(self):
        t = Transport('tcp')
        for i in range(32):
            t.admit(Request(str(i), str(i))); t.cancel(); self.result(t, 'cancelled')
        with self.assertRaises(ValueError): t.admit(Request('33', '33'))
        self.assertEqual(len(t.samples), 32)

    def test_validation_and_silence(self):
        self.assertEqual([silence_ms(b) for b in (9600, 19200, 38400, 115200)], [4, 2, 2, 2])
        for opts in ({'retries': True}, {'retries': 4}, {'request_timeout': 99},
                     {'policy': 'bounded'}, {'policy': 'bounded', 'late_bound': 500},
                     {'operation_timeout': 499}, {'baud': 12345}):
            with self.assertRaises(ValueError): Transport('rtu', **opts)
        t = Transport('tcp')
        for request in (Request('r', 'd', unit=256), Request('r', 'd', count=126),
                        Request('r', 'd', address=65535, count=2),
                        Request('r', 'd', function=6, safe_read=True)):
            with self.assertRaises(ValueError): t.admit(request)


if __name__ == '__main__':
    unittest.main()
