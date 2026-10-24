/* Linux-only internal C API. Not a stable Lua or package ABI. */
#ifndef OMC_IO_H
#define OMC_IO_H
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <poll.h>
#include <asm/termbits.h> /* kernel termios ABI; do not mix with libc termios.h */
#include <netinet/in.h>
#define OMC_IO_RX_MAX 512
#define OMC_IO_TX_MAX 260
#define OMC_IO_POLL_MAX 8 /* seven endpoints plus one wake descriptor */
enum omc_kind { OMC_CLOSED=0, OMC_SERIAL, OMC_TCP, OMC_WAKE };
typedef struct { int fd; enum omc_kind kind; } omc_handle;
#define OMC_HANDLE_INIT { -1, OMC_CLOSED }
/* All failing operations return -1 and set errno. No EINTR retry anywhere.
 * Each *_once operation issues at most one libc system-call primitive.
 * Caller owns buffers/handles and must serialize access; never copy a live handle.
 * The caller implements identity, readiness, deadlines and the four-call budget. */
int omc_clock_once(uint64_t *milliseconds);
int omc_serial_open_once(omc_handle *, const char *trusted_path);
int omc_tcp_open_once(omc_handle *);
int omc_wake_open_once(omc_handle *);
/* Pure preparation, no I/O, numeric IPv4 only; no DNS or implicit port default. */
int omc_ipv4(const char *, unsigned port, struct sockaddr_in *);
int omc_termios_8n1(unsigned baud, struct termios *);
int omc_configure_once(const omc_handle *, const struct termios *);
int omc_connect_once(const omc_handle *, const struct sockaddr_in *);
/* Call only after writable/error readiness; SO_ERROR=0 alone is not proof. */
int omc_connect_status_once(const omc_handle *);
ssize_t omc_read_once(const omc_handle *, void *, size_t);
ssize_t omc_write_once(const omc_handle *, const void *, size_t);
/* Driver evidence only: never promote these probes to wire TX capability alone. */
int omc_outq_once(const omc_handle *, int *queued);
int omc_lsr_once(const omc_handle *, int *empty);
int omc_poll_once(struct pollfd *, size_t count, int timeout_ms);
int omc_wake_once(const omc_handle *);
int omc_drain_wake_once(const omc_handle *, uint64_t *count);
/* Invalidates BEFORE close; Linux close errors must not be retried on that fd. */
int omc_close_once(omc_handle *);
#endif
