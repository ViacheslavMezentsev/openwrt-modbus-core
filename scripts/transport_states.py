"""Host-only RTU/TCP state machine, core 6.8; no sockets, serial or wall clock.

The caller supplies monotonic integer milliseconds and bounded I/O completions.
One admitted operation; an external scheduler owns queues, rounds and fairness.
This is an executable contract model, not the Lua runtime backend.
"""
from dataclasses import dataclass
import struct


def integer(value, low, high, name):
    if type(value) is not int or not low <= value <= high:
        raise ValueError(name)


def crc16(data):
    crc = 0xffff
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0xa001 if crc & 1 else 0)
    return crc


def rtu_frame(body):
    return body + struct.pack('<H', crc16(body))


def tcp_frame(tid, unit, pdu):
    return struct.pack('>HHHB', tid, 0, len(pdu) + 1, unit) + pdu


def silence_ms(baud):
    integer(baud, 1, 115200, 'baud')
    if baud not in (9600, 19200, 38400, 57600, 115200):
        raise ValueError('baud')
    # ceil(3.5 * 10 bits * 1000 / baud), or ceil(1.75 ms).
    return (35000 + baud - 1) // baud if baud <= 19200 else 2


@dataclass(frozen=True)
class Request:
    operation_id: str
    device_id: str
    unit: int = 1
    function: int = 3
    address: int = 0
    count: int = 1  # read quantity; FC06 value for the model's write probe
    safe_read: bool = False

    def pdu(self):
        return struct.pack('>BHH', self.function, self.address, self.count)


@dataclass(frozen=True)
class Result:
    operation_id: str
    device_id: str
    transport_id: str
    outcome: str
    attempts: int
    sent_attempts: int
    start: int
    end: int
    write_outcome: object
    exception_code: object = None
    data: bytes = b''


class Transport:
    """Each method is one bounded event. tick never loops through retries.

    generation is required on TCP setup/TX/RX/error callbacks. Old callbacks are
    ignored. tx() reports successful bytes (zero = EAGAIN); tx_complete() is an
    externally evidenced end of transmission, not a claim about USB timing.
    drain_results() transfers observations so history need not grow unbounded.
    """
    def __init__(self, kind, transport_id='line', *, request_timeout=500,
                 operation_timeout=10000, setup_timeout=1000, retries=0,
                 retry_delay=100, reconnect_delay=1000, policy='manual',
                 late_bound=None, timing_profile=None, baud=115200):
        if kind not in ('rtu', 'tcp') or not transport_id:
            raise ValueError('transport')
        for value, low, high, name in (
            (request_timeout, 100, 2000, 'request_timeout'),
            (operation_timeout, request_timeout, 60000, 'operation_timeout'),
            (setup_timeout, 100, 5000, 'setup_timeout'),
            (retries, 0, 3, 'retries'), (retry_delay, 0, 5000, 'retry_delay'),
            (reconnect_delay, 1000, 30000, 'reconnect_delay')):
            integer(value, low, high, name)
        if policy not in ('manual', 'bounded'):
            raise ValueError('policy')
        if policy == 'bounded':
            integer(late_bound, 1, 60000, 'late_bound')
            if not isinstance(timing_profile, str) or not timing_profile.strip():
                raise ValueError('timing evidence required')
        elif late_bound is not None or timing_profile is not None:
            raise ValueError('unused timing profile')
        self.kind, self.transport_id = kind, transport_id
        self.request_timeout, self.operation_timeout = request_timeout, operation_timeout
        self.setup_timeout, self.retries = setup_timeout, retries
        self.retry_delay, self.reconnect_delay = retry_delay, reconnect_delay
        self.policy, self.late_bound = policy, late_bound
        self.gap = silence_ms(baud)
        self.now = 0
        self.state = 'desynchronized' if kind == 'rtu' else 'idle'
        self.op = None
        self.results = []
        self.samples = {}
        self.current_device = None
        self.generation, self.next_tid, self.tid = 0, 0, None
        self.connected = False
        self.ready_at = 0
        self.rx = bytearray()
        self.wire = b''
        self.quarantine_end = self.quiet_end = 0
        self.sync_evidence = None

    @property
    def valid(self):
        return self.samples.get(self.current_device, {}).get('valid', False)

    @valid.setter
    def valid(self, value):
        if self.current_device is not None:
            self.samples[self.current_device]['valid'] = value

    @property
    def last_success(self):
        return self.samples.get(self.current_device, {}).get('last_success')

    @last_success.setter
    def last_success(self, value):
        self.samples[self.current_device]['last_success'] = value

    def _callback(self, generation):
        return self.kind != 'tcp' or generation == self.generation

    def confirm_sync(self, evidence):
        if self.kind != 'rtu' or self.op or not isinstance(evidence, str) or not evidence.strip():
            raise ValueError('explicit idle RTU recovery evidence required')
        self.sync_evidence = evidence
        self.state = 'idle'
        self.rx.clear()
        self.ready_at = self.now + self.gap
        # This records an external assertion; it does not reset real hardware.

    def admit(self, request, expiry=None):
        if self.op is not None or self.results or self.state == 'quarantine':
            return False  # bounded result slot must be consumed before admission
        if not isinstance(request, Request) or not request.operation_id or not request.device_id:
            raise ValueError('request identity')
        integer(request.unit, 1 if self.kind == 'rtu' else 0,
                247 if self.kind == 'rtu' else 255, 'unit')
        integer(request.function, 1, 6, 'function')
        if request.function not in (1, 2, 3, 4, 6):
            raise ValueError('model supports reads and FC06 write probe')
        integer(request.address, 0, 65535, 'address')
        limit = 2000 if request.function in (1, 2) else 125
        integer(request.count, 0 if request.function == 6 else 1,
                65535 if request.function == 6 else limit, 'count/value')
        if request.function != 6 and request.address + request.count > 65536:
            raise ValueError('read range')
        if type(request.safe_read) is not bool or (request.function == 6 and request.safe_read):
            raise ValueError('safe_read')
        if expiry is not None:
            integer(expiry, 0, 2**53 - 1, 'expiry')
        if request.device_id not in self.samples:
            if len(self.samples) >= 32:
                raise ValueError('logical device limit')
            self.samples[request.device_id] = {'valid': False, 'last_success': None}
        self.current_device = request.device_id
        self.op = request
        self.start = self.now
        self.dop = min(self.now + self.operation_timeout,
                       expiry if expiry is not None else self.now + self.operation_timeout)
        self.attempts = self.sent_attempts = self.sent = self.total_sent = 0
        self.da = None
        self.rx.clear()
        if self.state not in ('desynchronized', 'quarantine'):
            self.state = 'queued'
        return True

    def begin(self):
        """Scheduler selects an admitted FIFO head; no automatic next operation."""
        self.tick(self.now)
        if not self.op or self.state != 'queued' or self.now < self.ready_at:
            return False
        self._setup()
        return True

    def _setup(self):
        self.attempts += 1
        self.sent = 0
        self.tx_finished = False
        self.da = None
        self.rx.clear()
        self.state = 'setup'
        self.setup_deadline = min(self.dop, self.now + self.setup_timeout)
        if self.kind == 'tcp' and (not self.connected or self.next_tid > 65535):
            self.generation += 1
            self.next_tid = 0
            self.connected = False

    def setup_done(self, generation=None):
        if not self._callback(generation):
            return
        self.tick(self.now)
        if not self._callback(generation):
            return
        if self.state != 'setup' or not self.op:
            return
        if self.kind == 'tcp':
            self.connected = True
            self.tid = self.next_tid
            self.next_tid += 1
            self.wire = tcp_frame(self.tid, self.op.unit, self.op.pdu())
        else:
            self.wire = rtu_frame(bytes([self.op.unit]) + self.op.pdu())
        self.state = 'send'

    def tx(self, count, generation=None):
        if not self._callback(generation):
            return
        self.tick(self.now)
        if not self._callback(generation):
            return
        if not self.op or self.state != 'send':
            return
        integer(count, 0, len(self.wire) - self.sent, 'TX completion count')
        if self.da is None:
            self.da = min(self.dop, self.now + self.request_timeout)
        if count:
            if not self.sent:
                self.sent_attempts += 1
            self.sent += count
            self.total_sent += count
            self.last_write = self.now
        if self.sent == len(self.wire):
            self.state = 'tx_completion'

    def tx_complete(self, generation=None):
        if not self._callback(generation):
            return
        self.tick(self.now)
        if not self._callback(generation):
            return
        if self.op and self.state == 'tx_completion':
            self.state = 'receive'
            self.tx_finished = True
            if self.kind == 'rtu':
                self.ready_at = self.now + self.gap

    def _close(self):
        self.generation += 1  # invalidate callbacks immediately, before reconnect
        self.connected = False
        self.rx.clear()
        self.ready_at = max(self.ready_at, self.now + self.reconnect_delay)

    def _finish(self, outcome, exception=None, data=b''):
        if not self.op:
            return
        op = self.op
        write_outcome = None
        if op.function == 6:
            write_outcome = ('confirmed' if outcome == 'ok' else
                             'unknown' if self.total_sent else 'not_sent')
        self.results.append(Result(op.operation_id, op.device_id, self.transport_id,
                                   outcome, self.attempts, self.sent_attempts,
                                   self.start, self.now, write_outcome, exception, data))
        self.valid = outcome == 'ok'
        if self.valid:
            self.last_success = self.now
        self.op = None
        self.da = None
        self.rx.clear()
        if self.state not in ('quarantine', 'desynchronized'):
            self.state = 'idle'

    def _fail(self, outcome, retryable=False):
        if not self.op:
            return
        self.valid = False
        if self.kind == 'tcp':
            self._close()
        elif self.sent:
            if self.policy == 'bounded' and self.sent == len(self.wire) and self.tx_finished:
                self.state = 'quarantine'
                self.quarantine_end = self.last_write + self.late_bound
                self.quiet_end = max(self.now + self.gap, self.ready_at)
            else:
                self.state = 'desynchronized'
        self.rx.clear()
        eligible = (retryable and self.op.safe_read and self.op.function in (1, 2, 3, 4)
                    and self.attempts <= self.retries and self.now < self.dop
                    and self.state != 'desynchronized')
        if eligible:
            self.retry_at = max(self.now + self.retry_delay, self.ready_at)
            if self.state != 'quarantine':
                self.state = 'retry'
            self.da = None
        else:
            self._finish(outcome)

    def tick(self, now):
        integer(now, self.now, 2**53 - 1, 'monotonic clock')
        self.now = now
        if self.op and now >= self.dop:
            self._fail('timeout' if self.total_sent else 'expired')
        elif self.op and self.da is not None and now >= self.da:
            self._fail('timeout', True)
        elif self.op and self.state == 'setup' and now >= self.setup_deadline:
            self._fail('timeout', True)
        if self.state == 'quarantine' and now > self.quarantine_end and now >= self.quiet_end:
            self.state = 'retry' if self.op else 'idle'
            if not self.op:
                self.ready_at = now
        if self.op and self.state == 'retry' and now >= self.retry_at:
            self._setup()

    def io_error(self, generation=None):
        if not self._callback(generation):
            return
        self.tick(self.now)
        if not self._callback(generation):
            return
        if self.state in ('setup', 'send', 'tx_completion', 'receive'):
            self._fail('io_error', True)

    def cancel(self):
        self.tick(self.now)
        self._fail('cancelled')

    def receive(self, data, generation=None):
        if not self._callback(generation):
            return
        if not isinstance(data, bytes) or len(data) > 512:
            raise ValueError('bounded byte event required')
        self.tick(self.now)
        if not self._callback(generation):
            return
        if not data:
            if self.kind == 'tcp':
                self.io_error(generation)
            return
        if self.state == 'quarantine':
            if self.now > self.quarantine_end:
                self.state = 'desynchronized'
                self._finish('desynchronized')
            else:
                self.quiet_end = self.now + self.gap
            return
        if self.kind == 'rtu' and self.state == 'desynchronized':
            return
        if self.state != 'receive' or not self.op:
            if self.kind == 'tcp':
                self._close()
                self._finish('protocol_error')
            else:
                self.state = 'desynchronized'
                self._finish('desynchronized')
            self.valid = False
            return
        cap = 520 if self.kind == 'tcp' else 256
        if len(self.rx) + len(data) > cap:
            self._fail('protocol_error', self.kind == 'rtu')
            return
        self.rx.extend(data)
        if self.kind == 'tcp':
            self._parse_tcp()
        else:
            self.ready_at = self.now + self.gap
            self._parse_rtu()

    def _parse_tcp(self):
        if len(self.rx) < 7:
            return
        tid, protocol, length, unit = struct.unpack('>HHHB', self.rx[:7])
        if (protocol != 0 or not 2 <= length <= 254 or tid != self.tid
                or unit != self.op.unit):
            self._fail('protocol_error')
            return
        size = 6 + length
        if len(self.rx) < size:
            return
        pdu = bytes(self.rx[7:size])
        extra = len(self.rx) > size
        self._pdu(pdu)
        if extra:
            self._close()  # cannot retract a result already delivered

    def _parse_rtu(self):
        if len(self.rx) < 3:
            return
        unit, fc = self.rx[:2]
        if unit != self.op.unit or fc not in (self.op.function, self.op.function | 0x80):
            self._fail('protocol_error', True)
            return
        size = 5 if fc & 0x80 else 8 if fc == 6 else 5 + self.rx[2]
        if size > 256:
            self._fail('protocol_error', True)
            return
        if len(self.rx) < size:
            return
        frame = bytes(self.rx[:size])
        if crc16(frame) != 0:
            self._fail('protocol_error', True)
            return
        extra = len(self.rx) > size
        self._pdu(frame[1:-2])
        if extra:
            self.state = 'desynchronized'
            self.valid = False

    def _pdu(self, pdu):
        fc = self.op.function
        if len(pdu) == 2 and pdu[0] == (fc | 0x80) and pdu[1] != 0:
            self._finish('modbus_exception', pdu[1])
            return
        if fc == 6:
            good = pdu == self.op.pdu()
        else:
            count = (self.op.count + 7) // 8 if fc in (1, 2) else self.op.count * 2
            good = len(pdu) == count + 2 and pdu[:2] == bytes([fc, count])
        if good:
            self._finish('ok', data=pdu[2:])
        else:
            self._fail('protocol_error', self.kind == 'rtu')

    def drain_results(self):
        result, self.results = self.results, []
        return result
