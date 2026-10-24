/* Core TC-142: one primitive, no hidden retry or fallback; linker wrappers. */
#define _GNU_SOURCE
#include "omc_io.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <time.h>

static int calls, injected=EINTR;
static ssize_t result=-1;
static int hit(void) { ++calls; errno=injected; return (int)result; }
int __wrap_open(const char *p, int flags, ...) {
    assert(!strcmp(p,"/dev/fixture"));
    assert((flags&(O_NONBLOCK|O_CLOEXEC|O_NOCTTY|O_NOFOLLOW)) ==
           (O_NONBLOCK|O_CLOEXEC|O_NOCTTY|O_NOFOLLOW));
    return hit();
}
int __wrap_socket(int domain, int type, int protocol) {
    assert(domain==AF_INET && type==(SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC) && !protocol);
    return hit();
}
int __wrap_eventfd(unsigned initial, int flags) {
    assert(!initial && flags==(EFD_NONBLOCK|EFD_CLOEXEC)); return hit();
}
int __wrap_connect(int fd, const struct sockaddr *a, socklen_t n) {
    assert(fd==10 && a->sa_family==AF_INET && n==sizeof(struct sockaddr_in)); return hit();
}
int __wrap_getsockopt(int fd, int level, int option, void *value, socklen_t *n) {
    assert(fd==10 && level==SOL_SOCKET && option==SO_ERROR && *n==sizeof(int));
    if (result==0) *(int *)value=injected;
    return hit();
}
ssize_t __wrap_read(int fd, void *buffer, size_t n) {
    assert(fd==10 && buffer && n); return hit();
}
ssize_t __wrap_write(int fd, const void *buffer, size_t n) {
    assert(fd==10 && buffer && n); return hit();
}
ssize_t __wrap_recv(int fd, void *buffer, size_t n, int flags) {
    assert(flags==MSG_DONTWAIT); return __wrap_read(fd,buffer,n);
}
ssize_t __wrap_send(int fd, const void *buffer, size_t n, int flags) {
    assert(flags==(MSG_DONTWAIT|MSG_NOSIGNAL)); return __wrap_write(fd,buffer,n);
}
int __wrap_ioctl(int fd, unsigned long request, ...) {
    assert(fd==10 && (request==TCSETS || request==TIOCOUTQ || request==TIOCSERGETLSR));
    return hit();
}
int __wrap_poll(struct pollfd *p, nfds_t n, int timeout) {
    assert(n==1 && p[0].fd==10 && !p[0].revents && timeout==0); return hit();
}
int __wrap_clock_gettime(clockid_t clock, struct timespec *t) {
    assert(clock==CLOCK_MONOTONIC && t); return hit();
}
int __wrap_close(int fd) { assert(fd==10 || fd==0); return hit(); }
#define FAIL_ONCE(expr) do { calls=0; errno=0; assert((expr)==-1); assert(errno==injected && calls==1); } while (0)
#define INVALID(expr) do { calls=0; errno=0; assert((expr)==-1); assert(errno==EINVAL && !calls); } while (0)
int main(void) {
    omc_handle h=OMC_HANDLE_INIT, serial={10,OMC_SERIAL}, tcp={10,OMC_TCP}, wake={10,OMC_WAKE};
    struct termios t;
    struct sockaddr_in a;
    struct pollfd p={10,POLLIN,POLLIN};
    char buffer[513]={0};
    uint64_t value=123;
    int output=456;
    const int errors[]={EINTR,EAGAIN,EIO};
    size_t i;
    assert(!omc_termios_8n1(115200,&t)); assert(!omc_ipv4("127.0.0.1",502,&a));
    for (i=0;i<sizeof(errors)/sizeof(errors[0]);++i) {
        injected=errors[i];
        FAIL_ONCE(omc_serial_open_once(&h,"/dev/fixture")); assert(h.fd==-1);
        FAIL_ONCE(omc_tcp_open_once(&h)); assert(h.fd==-1);
        FAIL_ONCE(omc_wake_open_once(&h)); assert(h.fd==-1);
        FAIL_ONCE(omc_clock_once(&value)); assert(value==123);
        FAIL_ONCE(omc_configure_once(&serial,&t));
        FAIL_ONCE(omc_connect_once(&tcp,&a));
        FAIL_ONCE(omc_connect_status_once(&tcp));
        FAIL_ONCE(omc_read_once(&serial,buffer,512));
        FAIL_ONCE(omc_read_once(&tcp,buffer,512));
        FAIL_ONCE(omc_write_once(&serial,buffer,260));
        FAIL_ONCE(omc_write_once(&tcp,buffer,260));
        FAIL_ONCE(omc_outq_once(&serial,&output)); assert(output==456);
        FAIL_ONCE(omc_lsr_once(&serial,&output)); assert(output==456);
        p.revents=POLLIN; FAIL_ONCE(omc_poll_once(&p,1,0)); assert(!p.revents);
        FAIL_ONCE(omc_wake_once(&wake));
        FAIL_ONCE(omc_drain_wake_once(&wake,&value)); assert(value==123);
        h=tcp; FAIL_ONCE(omc_close_once(&h)); assert(h.fd==-1 && h.kind==OMC_CLOSED);
        INVALID(omc_close_once(&h));
    }
    /* A short write is not completed by an internal loop. Zero/EOF is preserved. */
    result=2; calls=0; assert(omc_write_once(&tcp,buffer,260)==2 && calls==1);
    result=0; calls=0; assert(omc_read_once(&tcp,buffer,1)==0 && calls==1);
    calls=0; assert(omc_write_once(&serial,buffer,1)==0 && calls==1);
    injected=ECONNREFUSED; FAIL_ONCE(omc_connect_status_once(&tcp));
    injected=0; calls=0; assert(!omc_connect_status_once(&tcp) && calls==1);
    /* fd zero is a valid acquired resource; double-open must not leak it. */
    calls=0; assert(!omc_tcp_open_once(&h) && h.fd==0 && calls==1);
    INVALID(omc_tcp_open_once(&h)); calls=0; assert(!omc_close_once(&h) && calls==1);
    INVALID(omc_read_once(&tcp,buffer,513)); INVALID(omc_read_once(&tcp,buffer,0));
    INVALID(omc_write_once(&tcp,buffer,261)); INVALID(omc_write_once(&tcp,NULL,1));
    INVALID(omc_poll_once(&p,9,0)); INVALID(omc_poll_once(&p,1,101));
    INVALID(omc_poll_once(&p,1,-1)); INVALID(omc_poll_once(NULL,1,0));
    INVALID(omc_configure_once(&tcp,&t)); INVALID(omc_wake_once(&tcp));
    INVALID(omc_serial_open_once(&h,"relative"));
    INVALID(omc_termios_8n1(0,&t)); INVALID(omc_termios_8n1(12345,&t));
    INVALID(omc_ipv4("localhost",502,&a)); INVALID(omc_ipv4("127.0.0.1",0,&a));
    INVALID(omc_ipv4("127.0.0.1",65536,&a));
    puts("native fault tests PASS: EINTR/EAGAIN/EIO, short I/O, bounds, fd lifecycle");
    return 0;
}
