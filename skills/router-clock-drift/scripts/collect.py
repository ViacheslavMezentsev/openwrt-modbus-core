#!/usr/bin/env python3
"""Collect an authorized, already deployed RAW probe. No install/time/NTP writes."""
import argparse, ipaddress, json, os, re, socket, subprocess, time
from pathlib import Path
from analyze import decode

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('host','probe','sha256'):p.add_argument('--'+name,required=True)
 p.add_argument('--server',action='append',required=True);p.add_argument('--out',type=Path,required=True)
 p.add_argument('--interval',type=int,default=300);p.add_argument('--samples',type=int,default=289)
 a=p.parse_args()
 if not re.fullmatch(r'[a-zA-Z0-9_][a-zA-Z0-9_.@-]*',a.host) or not re.fullmatch(r'/tmp/[a-zA-Z0-9_-]+/probe',a.probe) or not re.fullmatch('[0-9a-f]{64}',a.sha256):p.error('host, isolated probe path or SHA256 invalid')
 if not 2<=len(a.server)<=4 or not 60<=a.interval<=86400 or not 2<=a.samples<=10000:p.error('require 2..4 references, interval 60..86400, samples 2..10000')
 # Reserve output before contacting hardware; refuse every restart/overwrite.
 a.out.mkdir(parents=True,exist_ok=False)
 def ssh(command,timeout=18):
  return subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=5',a.host,command],capture_output=True,text=True,timeout=timeout)
 check=ssh('sha256sum '+a.probe)
 if check.returncode or not check.stdout.split() or check.stdout.split()[0]!=a.sha256:raise RuntimeError('remote probe hash mismatch')
 run=vars(a).copy();run['out']=str(a.out);run.update(pid=os.getpid(),start_utc=time.time())
 (a.out/'run.json').write_text(json.dumps(run,indent=2))
 def status(value):
  (a.out/'status.tmp').write_text(json.dumps(value));(a.out/'status.tmp').replace(a.out/'status.json');print(json.dumps(value),flush=True)
 start=time.monotonic()
 try:
  for seq in range(a.samples):
   due=start+seq*a.interval
   if time.monotonic()-due>min(30,a.interval/2):raise RuntimeError('missed interval; no catch-up requests')
   time.sleep(max(0,due-time.monotonic()))
   row={'seq':seq,'host_utc':time.time(),'peers':[]}
   for server in a.server:
    v={'server':server}
    try:
     ip=str(ipaddress.IPv4Address(socket.gethostbyname(server)));v['ip']=ip
     result=ssh(a.probe+' '+ip);v.update(returncode=result.returncode,stderr=result.stderr)
     if result.returncode:raise RuntimeError('probe exit '+str(result.returncode))
     v.update(json.loads(result.stdout));decode(v);v['valid']=True
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired)as e:v.update(valid=False,error=str(e))
    row['peers'].append(v)
   row['ok']=all(v['valid']for v in row['peers'])
   with (a.out/'samples.jsonl').open('a')as f:f.write(json.dumps(row)+'\n');f.flush()
   status({'state':'complete'if seq+1==a.samples else 'running','seq':seq,'ok':row['ok'],'updated_utc':time.time()})
 except BaseException as e:
  status({'state':'failed','error':str(e),'updated_utc':time.time()});raise
if __name__=='__main__':main()
