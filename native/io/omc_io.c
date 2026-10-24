#define _GNU_SOURCE
#include "omc_io.h"
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/serial.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

static int fail(int error) { errno=error; return -1; }
static int empty_handle(const omc_handle *h) {
    return h && h->fd == -1 && h->kind == OMC_CLOSED;
}
static int kind(const omc_handle *h, enum omc_kind k) {
    return h && h->fd >= 0 && h->kind == k;
}
static int data_handle(const omc_handle *h) {
    return kind(h, OMC_SERIAL) || kind(h, OMC_TCP);
}
static int opened(omc_handle *h, int fd, enum omc_kind k) {
    if (fd < 0) return -1;
    h->fd=fd; h->kind=k; return 0;
}
/* Core 6.10.3/6.10.10: no loops, DNS, hidden fcntl or tcdrain. */
int omc_clock_once(uint64_t *ms) {
    struct timespec t;
    if (!ms) return fail(EINVAL);
    if (clock_gettime(CLOCK_MONOTONIC, &t) < 0) return -1;
    if (t.tv_sec < 0 || (uint64_t)t.tv_sec > UINT64_MAX/1000-1)
        return fail(EOVERFLOW);
    *ms=(uint64_t)t.tv_sec*1000+(uint64_t)t.tv_nsec/1000000;
    return 0;
}
int omc_serial_open_once(omc_handle *h, const char *path) {
    if (!empty_handle(h) || !path || path[0] != '/') return fail(EINVAL);
    return opened(h, open(path, O_RDWR|O_NOCTTY|O_NONBLOCK|O_CLOEXEC|O_NOFOLLOW), OMC_SERIAL);
}
int omc_tcp_open_once(omc_handle *h) {
    if (!empty_handle(h)) return fail(EINVAL);
    return opened(h, socket(AF_INET, SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC, 0), OMC_TCP);
}
int omc_wake_open_once(omc_handle *h) {
    if (!empty_handle(h)) return fail(EINVAL);
    return opened(h, eventfd(0, EFD_NONBLOCK|EFD_CLOEXEC), OMC_WAKE);
}
int omc_ipv4(const char *address, unsigned port, struct sockaddr_in *out) {
    struct sockaddr_in a;
    if (!address || !out || !port || port>65535) return fail(EINVAL);
    memset(&a, 0, sizeof(a));
    a.sin_family=AF_INET; a.sin_port=htons((uint16_t)port);
    if (inet_pton(AF_INET, address, &a.sin_addr) != 1) return fail(EINVAL);
    *out=a; return 0;
}
int omc_termios_8n1(unsigned baud, struct termios *out) {
    struct termios t;
    unsigned speed;
    if (!out) return fail(EINVAL);
    switch (baud) {
    case 1200: speed=B1200; break;
    case 2400: speed=B2400; break;
    case 4800: speed=B4800; break;
    case 9600: speed=B9600; break;
    case 19200: speed=B19200; break;
    case 38400: speed=B38400; break;
    case 57600: speed=B57600; break;
    case 115200: speed=B115200; break;
    default: return fail(EINVAL);
    }
    memset(&t, 0, sizeof(t));
    t.c_cflag=CS8|CREAD|CLOCAL|speed; /* no parity, stop=1, flow control, HUPCL */
    t.c_cc[VMIN]=0; t.c_cc[VTIME]=0;
    *out=t; return 0;
}
int omc_configure_once(const omc_handle *h, const struct termios *t) {
    if (!kind(h, OMC_SERIAL) || !t) return fail(EINVAL);
    return ioctl(h->fd, TCSETS, t);
}
int omc_connect_once(const omc_handle *h, const struct sockaddr_in *a) {
    if (!kind(h, OMC_TCP) || !a || a->sin_family != AF_INET || !a->sin_port)
        return fail(EINVAL);
    return connect(h->fd, (const struct sockaddr *)a, sizeof(*a));
}
int omc_connect_status_once(const omc_handle *h) {
    int error=0;
    socklen_t length=sizeof(error);
    if (!kind(h, OMC_TCP)) return fail(EINVAL);
    if (getsockopt(h->fd, SOL_SOCKET, SO_ERROR, &error, &length) < 0) return -1;
    if (length != sizeof(error)) return fail(EIO);
    return error ? fail(error) : 0;
}
ssize_t omc_read_once(const omc_handle *h, void *buffer, size_t size) {
    if (!data_handle(h) || !buffer || !size || size>OMC_IO_RX_MAX) return fail(EINVAL);
    if (h->kind == OMC_TCP) return recv(h->fd, buffer, size, MSG_DONTWAIT);
    return read(h->fd, buffer, size);
}
ssize_t omc_write_once(const omc_handle *h, const void *buffer, size_t size) {
    if (!data_handle(h) || !buffer || !size || size>OMC_IO_TX_MAX) return fail(EINVAL);
    if (h->kind == OMC_TCP)
        return send(h->fd, buffer, size, MSG_DONTWAIT|MSG_NOSIGNAL);
    return write(h->fd, buffer, size);
}
int omc_outq_once(const omc_handle *h, int *queued) {
    int n;
    if (!kind(h, OMC_SERIAL) || !queued) return fail(EINVAL);
    if (ioctl(h->fd, TIOCOUTQ, &n) < 0) return -1;
    *queued=n; return 0;
}
int omc_lsr_once(const omc_handle *h, int *empty) {
    int flags;
    if (!kind(h, OMC_SERIAL) || !empty) return fail(EINVAL);
    if (ioctl(h->fd, TIOCSERGETLSR, &flags) < 0) return -1;
    *empty=!!(flags&TIOCSER_TEMT); return 0;
}
int omc_poll_once(struct pollfd *fds, size_t count, int timeout) {
    size_t i;
    if (count>OMC_IO_POLL_MAX || (count && !fds) || timeout<0 || timeout>100)
        return fail(EINVAL);
    /* Clear previous results. Caller discards revents if poll fails. */
    for (i=0; i<count; ++i) fds[i].revents=0;
    return poll(fds, (nfds_t)count, timeout);
}
int omc_wake_once(const omc_handle *h) {
    const uint64_t one=1;
    ssize_t n;
    if (!kind(h, OMC_WAKE)) return fail(EINVAL);
    n=write(h->fd, &one, sizeof(one));
    return n<0 ? -1 : n==(ssize_t)sizeof(one) ? 0 : fail(EIO);
}
int omc_drain_wake_once(const omc_handle *h, uint64_t *count) {
    uint64_t value;
    ssize_t n;
    if (!kind(h, OMC_WAKE) || !count) return fail(EINVAL);
    n=read(h->fd, &value, sizeof(value));
    if (n<0) return -1;
    if (n != sizeof(value)) return fail(EIO);
    *count=value; return 0;
}
int omc_close_once(omc_handle *h) {
    int fd;
    if (!h || h->fd < 0 || h->kind < OMC_SERIAL || h->kind > OMC_WAKE)
        return fail(EINVAL);
    fd=h->fd; h->fd=-1; h->kind=OMC_CLOSED;
    return close(fd);
}
