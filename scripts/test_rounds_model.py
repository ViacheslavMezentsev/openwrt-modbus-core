"""Core TC-74..82: partial host-model coverage only; see spec appendix K."""
import unittest
from rounds_model import Model, Port, Request


PORTS = [Port('a', 'wire-a'), Port('b', 'wire-b'), Port('c', 'wire-c')]


def req(id, port='a', delay=10, ready=0, timeout=600, outcome='ok'):
    return Request(id, port, 1, ready, timeout, delay, outcome)


def events(run, kind):
    return [e for e in run['trace'] if e['kind'] == kind]


class RoundsTests(unittest.TestCase):
    def test_barrier_and_immediate_results(self):
        run = Model(PORTS).run([req(p+str(i), p, d) for i in range(2)
                               for p, d in [('a', 10), ('b', 20), ('c', 500)]])
        self.assertEqual([(e['id'], e['at']) for e in events(run, 'start')],
                         [('a0', 0), ('b0', 0), ('c0', 0), ('a1', 500), ('b1', 500), ('c1', 500)])
        self.assertEqual([e['at'] for e in run['results']], [10, 20, 500, 510, 520, 1000])
        self.assertEqual([e['at'] for e in events(run, 'barrier')], [500, 1000])

    def test_sequential_comparison(self):
        work = [req('a', 'a', 10), req('b', 'b', 20), req('c', 'c', 500)]
        self.assertEqual(Model(PORTS).run(work)['elapsed'], 500)
        self.assertEqual(Model(PORTS, mode='sequential').run(work)['elapsed'], 530)

    def test_same_unit_isolated(self):
        run = Model(PORTS).run([req('a'), req('b', 'b', 20, outcome='error')])
        self.assertTrue(run['cache'][('a', 1)]['valid'])
        self.assertFalse(run['cache'][('b', 1)]['valid'])
        self.assertEqual(run['cache'][('a', 1)]['last_success'], 10)

    def test_timeout_disconnect_and_next_round(self):
        run = Model(PORTS).run([req('fast'), req('silent', 'b', None, timeout=100),
                               req('gone', 'c', 15, outcome='disconnect'), req('next')])
        self.assertEqual([(e['id'], e['outcome'], e['at']) for e in run['results']],
                         [('fast', 'ok', 10), ('gone', 'disconnect', 15),
                          ('silent', 'timeout', 100), ('next', 'ok', 110)])

    def test_arrival_during_round_waits(self):
        run = Model(PORTS).run([req('first', delay=50), req('later', 'b', ready=1)])
        self.assertEqual([e['at'] for e in events(run, 'start')], [0, 50])

    def test_unavailable_and_empty_ports_do_not_join(self):
        run = Model([PORTS[0], Port('b', 'wire-b', 100), PORTS[2]]).run(
            [req('a'), req('b', 'b')])
        self.assertEqual([e['ports'] for e in events(run, 'round_start')], [['a'], ['b']])
        self.assertEqual([e['at'] for e in run['results']], [10, 110])

    def test_service_during_silent_wait(self):
        run = Model(PORTS, quantum=7).run([req('silent', delay=None, timeout=100)])
        self.assertEqual([e['at'] for e in events(run, 'service')], list(range(7, 100, 7)))
        self.assertEqual(run['elapsed'], 100)

    def test_empty_and_idle_event_jumps(self):
        self.assertEqual(Model(PORTS).run([])['steps'], 0)
        run = Model(PORTS, quantum=100).run([req('later', ready=1000)])
        self.assertLess(run['steps'], 15)
        self.assertEqual(run['elapsed'], 1010)

    def test_fifo_finite_workload(self):
        work = [req(str(i), 'ab'[i % 2], delay=1) for i in range(12)]
        run = Model(PORTS).run(work)
        for port in 'ab':
            self.assertEqual([e['id'] for e in run['results'] if e['port'] == port],
                             [q.id for q in work if q.port == port])

    def test_single_port_matches_baseline(self):
        work = [req('a', delay=3), req('b', delay=None, timeout=12), req('c', delay=0)]
        a = Model(PORTS[:1]).run(work)
        b = Model(PORTS[:1], mode='sequential').run(work)
        self.assertEqual(a, b)
        self.assertEqual(a['elapsed'], 15)

    def test_deadline_tie_is_timeout_model_assumption(self):
        run = Model(PORTS).run([req('tie', delay=10, timeout=10)])
        self.assertEqual(run['results'][0]['outcome'], 'timeout')

    def test_failed_refresh_keeps_timestamp_not_validity(self):
        run = Model(PORTS).run([req('ok'), req('bad', outcome='error')])
        self.assertEqual(run['cache'][('a', 1)], dict(valid=False, last_success=10))

    def test_reject_queue_overflow(self):
        run = Model(PORTS, queue_limit=1).run([req('one'), req('two')])
        self.assertEqual(run['results'][0]['outcome'], 'rejected')
        self.assertIsNone(run['results'][0]['started'])
        self.assertEqual(len(events(run, 'start')), 1)

    def test_delayed_outcome_cannot_complete_after_deadline(self):
        run = Model(PORTS).run([req('late', delay=200, timeout=10), req('fresh', delay=2)])
        self.assertEqual([(e['id'], e['outcome'], e['at']) for e in run['results']],
                         [('late', 'timeout', 10), ('fresh', 'ok', 12)])
        # Oracle discards the late outcome; this does NOT test byte-level RTU resync.

    def test_repeatable_and_input_not_mutated(self):
        work = [req('one'), req('two', 'b', delay=None, timeout=20)]
        before = list(work)
        model = Model(PORTS)
        self.assertEqual(model.run(work), model.run(work))
        self.assertEqual(work, before)

    def test_invalid_inputs_and_step_budget(self):
        with self.assertRaises(ValueError):
            Model([PORTS[0], Port('b', 'wire-a')])
        for work in [[req('x', 'unknown')], [req('x'), req('x')],
                     [req('x', timeout=0)], [req('x', delay=-1)], [req('x', ready=True)]]:
            with self.assertRaises(ValueError):
                Model(PORTS).run(work)
        with self.assertRaises(ValueError):
            Model(PORTS, max_requests=1).run([req('x'), req('y')])
        with self.assertRaises(RuntimeError):
            Model(PORTS, max_steps=2).run([req('x', delay=100)])


if __name__ == '__main__':
    unittest.main()
