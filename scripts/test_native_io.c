/* Core TC-143: real Linux host TCP/PTY/eventfd. No router or physical tty. */
#define _GNU_SOURCE
#include "omc_io.h"
#include <assert.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

static void flags(const omc_handle *h) {
    assert(fcntl(h->fd,F_GETFL)&O_NONBLOCK);
    assert(fcntl(h->fd,F_GETFD)&FD_CLOEXEC);
}
static unsigned fd_count(void) {
    DIR *d=opendir("/proc/self/fd"); struct dirent *entry; unsigned n=0;
    assert(d); while ((entry=readdir(d))) if (entry->d_name[0]!='.') ++n;
    assert(!closedir(d)); return n;
}
static void wait_ready(int fd, short events) {
    struct pollfd p={fd,events,0};
    assert(omc_poll_once(&p,1,100)==1); assert(p.revents&(events|POLLERR|POLLHUP));
}
static void wake_test(void) {
    omc_handle w=OMC_HANDLE_INIT; uint64_t n=0;
    struct pollfd p;
    assert(!omc_wake_open_once(&w)); flags(&w);
    assert(omc_drain_wake_once(&w,&n)==-1 && errno==EAGAIN);
    assert(!omc_wake_once(&w)); assert(!omc_wake_once(&w));
    wait_ready(w.fd,POLLIN); assert(!omc_drain_wake_once(&w,&n) && n==2);
    p.fd=w.fd; p.events=POLLIN; assert(omc_poll_once(&p,1,0)==0);
    n=UINT64_MAX-1; assert(write(w.fd,&n,8)==8);
    assert(omc_wake_once(&w)==-1 && errno==EAGAIN);
    assert(!omc_drain_wake_once(&w,&n) && n==UINT64_MAX-1);
    assert(!omc_close_once(&w));
}
static void tcp_test(void) {
    struct sockaddr_in a; socklen_t length=sizeof(a);
    int server=socket(AF_INET,SOCK_STREAM|SOCK_CLOEXEC,0), peer, rc;
    omc_handle h=OMC_HANDLE_INIT;
    char buffer[512];
    assert(server>=0); assert(!omc_ipv4("127.0.0.1",1,&a)); a.sin_port=0;
    assert(!bind(server,(struct sockaddr *)&a,sizeof(a)));
    assert(!getsockname(server,(struct sockaddr *)&a,&length)); assert(!listen(server,1));
    assert(!omc_tcp_open_once(&h)); flags(&h);
    rc=omc_connect_once(&h,&a); assert(!rc || (rc==-1 && errno==EINPROGRESS));
    wait_ready(h.fd,POLLOUT); assert(!omc_connect_status_once(&h));
    peer=accept(server,NULL,NULL); assert(peer>=0);
    assert(omc_read_once(&h,buffer,sizeof(buffer))==-1 && errno==EAGAIN);
    assert(omc_write_once(&h,"abc",3)==3); assert(read(peer,buffer,3)==3 && !memcmp(buffer,"abc",3));
    memset(buffer,0xa5,sizeof(buffer)); assert(write(peer,buffer,512)==512);
    wait_ready(h.fd,POLLIN); assert(omc_read_once(&h,buffer,512)==512);
    assert((unsigned char)buffer[511]==0xa5);
    assert(!close(peer)); wait_ready(h.fd,POLLIN); assert(omc_read_once(&h,buffer,512)==0);
    assert(!omc_close_once(&h)); assert(!close(server));
    /* A bound, non-listening port deterministically refuses the connection. */
    server=socket(AF_INET,SOCK_STREAM,0); assert(server>=0); a.sin_port=0;
    assert(!bind(server,(struct sockaddr *)&a,sizeof(a)));
    assert(!getsockname(server,(struct sockaddr *)&a,&length));
    assert(!omc_tcp_open_once(&h)); rc=omc_connect_once(&h,&a);
    if (rc==-1 && errno==EINPROGRESS) {
        wait_ready(h.fd,POLLOUT); assert(omc_connect_status_once(&h)==-1 && errno==ECONNREFUSED);
    } else assert(rc==-1 && errno==ECONNREFUSED);
    assert(!omc_close_once(&h)); assert(!close(server));
}
static void sigpipe_test(void) {
    int fds[2]; omc_handle h;
    assert(signal(SIGPIPE,SIG_DFL)!=SIG_ERR);
    assert(!socketpair(AF_UNIX,SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC,0,fds));
    h.fd=fds[0]; h.kind=OMC_TCP; assert(!close(fds[1]));
    assert(omc_write_once(&h,"x",1)==-1 && errno==EPIPE); /* process survives */
    assert(!omc_close_once(&h));
}
static void pty_test(void) {
    int master=posix_openpt(O_RDWR|O_NOCTTY|O_NONBLOCK|O_CLOEXEC), queued, empty=99, rc;
    struct termios settings, actual;
    omc_handle h=OMC_HANDLE_INIT;
    char buffer[32]; const char payload[]={0,10,13,0x11,0x13,0x7f,(char)0xff};
    assert(master>=0 && !grantpt(master) && !unlockpt(master));
    assert(!omc_serial_open_once(&h,ptsname(master))); flags(&h);
    assert(!omc_termios_8n1(115200,&settings)); assert(!omc_configure_once(&h,&settings));
    assert(!ioctl(h.fd,TCGETS,&actual));
    assert((actual.c_cflag&CSIZE)==CS8 && !(actual.c_cflag&(PARENB|CSTOPB|CRTSCTS|HUPCL)));
    assert((actual.c_cflag&CBAUD)==B115200 && !actual.c_iflag && !actual.c_oflag && !actual.c_lflag);
    assert(!actual.c_cc[VMIN] && !actual.c_cc[VTIME]);
    assert(write(master,payload,sizeof(payload))==sizeof(payload));
    wait_ready(h.fd,POLLIN); assert(omc_read_once(&h,buffer,sizeof(buffer))==sizeof(payload));
    assert(!memcmp(buffer,payload,sizeof(payload)));
    assert(omc_write_once(&h,payload,sizeof(payload))==sizeof(payload));
    wait_ready(master,POLLIN); assert(read(master,buffer,sizeof(buffer))==sizeof(payload));
    assert(!memcmp(buffer,payload,sizeof(payload)));
    assert(!omc_outq_once(&h,&queued) && queued==0);
    rc=omc_lsr_once(&h,&empty);
    assert(rc==-1 && (errno==ENOTTY || errno==EINVAL || errno==EOPNOTSUPP) && empty==99);
    assert(!omc_close_once(&h)); assert(!close(master));
}
static volatile sig_atomic_t interrupted;
static void alarm_handler(int sig) { (void)sig; interrupted=1; }
static void interrupt_test(void) {
    struct sigaction a; struct itimerval timer; uint64_t before,after;
    memset(&a,0,sizeof(a)); a.sa_handler=alarm_handler; sigemptyset(&a.sa_mask);
    assert(!sigaction(SIGALRM,&a,NULL)); memset(&timer,0,sizeof(timer));
    timer.it_value.tv_usec=10000; assert(!omc_clock_once(&before));
    assert(!setitimer(ITIMER_REAL,&timer,NULL));
    assert(omc_poll_once(NULL,0,100)==-1 && errno==EINTR && interrupted);
    assert(!omc_clock_once(&after) && after>=before);
}
int main(void) {
    unsigned before=fd_count(), i;
    uint64_t a,b;
    assert(!omc_clock_once(&a) && !omc_clock_once(&b) && b>=a);
    wake_test(); tcp_test(); sigpipe_test(); pty_test(); interrupt_test();
    for (i=0;i<200;++i) {
        omc_handle h=OMC_HANDLE_INIT;
        assert(!omc_tcp_open_once(&h)); assert(!omc_close_once(&h));
        assert(!omc_wake_open_once(&h)); assert(!omc_close_once(&h));
    }
    assert(fd_count()==before);
    puts("native host tests PASS: TCP, raw PTY, wake saturation, poll EINTR, SIGPIPE, 200 FD cycles");
    return 0;
}
