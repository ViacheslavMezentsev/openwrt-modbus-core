#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <sys/timex.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdlib.h>
static double clk(int id){struct timespec t;if(clock_gettime(id,&t))exit(2);return t.tv_sec+t.tv_nsec/1e9;}
static void hex(unsigned char*p,int n){int i;for(i=0;i<n;i++)printf("%02x",p[i]);}
int main(int argc,char**argv){
 if(argc!=2)return 2;
 alarm(12);
 struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_port=htons(123);if(inet_pton(AF_INET,argv[1],&a.sin_addr)!=1)return 2;
 int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)return 3;struct timeval timeout={3,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);if(connect(fd,(void*)&a,sizeof a))return 4;
 char boot[80]={0};FILE*f=fopen("/proc/sys/kernel/random/boot_id","r");if(!f)return 5;if(fscanf(f,"%79s",boot)!=1)return 5;fclose(f);
 char source[80]={0};f=fopen("/sys/devices/system/clocksource/clocksource0/current_clocksource","r");if(!f)return 9;if(fscanf(f,"%79s",source)!=1)return 9;fclose(f);
 struct timex tx;memset(&tx,0,sizeof tx);int state=adjtimex(&tx);if(state<0)return 8; /* modes=0: read only */
 unsigned char req[48]={0},resp[512];req[0]=0x23;double real=clk(CLOCK_REALTIME);uint32_t sec=htonl((uint32_t)real+2208988800U),frac=htonl((uint32_t)((real-(uint32_t)real)*4294967296.0));memcpy(req+40,&sec,4);memcpy(req+44,&frac,4);
 double mono=clk(CLOCK_MONOTONIC),lo=clk(CLOCK_MONOTONIC_RAW);if(send(fd,req,48,0)!=48)return 6;int n=recv(fd,resp,sizeof resp,0);double hi=clk(CLOCK_MONOTONIC_RAW);close(fd);if(n<48){fprintf(stderr,"ntp receive failed: %d\n",n);return 7;}
 printf("{\"boot\":\"%s\",\"clocksource\":\"%s\",\"raw_lo\":%.9f,\"raw_hi\":%.9f,\"mono\":%.9f,\"real\":%.9f,\"timex_state\":%d,\"timex_status\":%d,\"freq_scaled\":%ld,\"maxerror_us\":%ld,\"request\":\"",boot,source,lo,hi,mono,real,state,tx.status,tx.freq,tx.maxerror);hex(req,48);printf("\",\"response\":\"");hex(resp,n);puts("\"}");return 0;
}
