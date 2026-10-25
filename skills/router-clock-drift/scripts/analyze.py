#!/usr/bin/env python3
"""Offline conditional RAW/NTP intervals. Never sets clocks or contacts servers."""
import argparse, collections, decimal, json, math, random, struct
from pathlib import Path
D=decimal.Decimal
decimal.getcontext().prec=45

def decode(row,margin='0.001'):
 if not D(margin).is_finite() or D(margin)<0:raise ValueError('server margin')
 p=bytes.fromhex(row['response']);q=bytes.fromhex(row['request'])
 if len(p)<48 or len(q)!=48 or p[0]&7!=4 or (p[0]>>3)&7 not in (3,4):raise ValueError('NTP mode/version/length')
 if p[0]>>6==3 or not 1<=p[1]<=15 or p[24:32]!=q[40:48]:raise ValueError('NTP unsynchronized/KoD/originate')
 def stamp(off):
  sec,frac=struct.unpack_from('!II',p,off);return D(sec-2208988800)+D(frac)/D(2**32)
 rx,tx=stamp(32),stamp(40)
 if not D(1700000000)<rx<=tx<D(2085978496):raise ValueError('NTP timestamps/era')
 lo,hi=D(str(row['raw_lo'])),D(str(row['raw_hi']))
 if not lo.is_finite() or not hi.is_finite() or not 0<hi-lo<4:raise ValueError('RAW bracket')
 delay=D(struct.unpack_from('!i',p,4)[0])/65536
 disp=D(struct.unpack_from('!I',p,8)[0])/65536
 precision=D(2)**struct.unpack_from('!b',p,3)[0]
 error=abs(delay)/2+disp+precision+D(margin)
 if not 0<=error<1:raise ValueError('server uncertainty')
 return dict(row,server_time=tx,server_error=error,raw_lo=lo,raw_hi=hi)

def estimate(a,b,local='0.000010'):
 if (a['boot'],a.get('clocksource'))!=(b['boot'],b.get('clocksource')):raise ValueError('epoch changed')
 if a.get('server')!=b.get('server'):raise ValueError('different reference')
 delta=D(str(b['server_time']))-D(str(a['server_time']));err=D(str(a['server_error']))+D(str(b['server_error']))
 allowance=D(local)
 if not allowance.is_finite() or allowance<0:raise ValueError('local allowance')
 lo=D(str(b['raw_lo']))-D(str(a['raw_hi']))-2*allowance
 hi=D(str(b['raw_hi']))-D(str(a['raw_lo']))+2*allowance
 if not delta>err>=0 or not hi>=lo>0:raise ValueError('short/reversed window')
 return [float((lo/(delta+err)-1)*1000000),float((hi/(delta-err)-1)*1000000)]

def report(rows,local='0.000010',margin='0.001'):
 groups=collections.defaultdict(list);errors=[]
 for row in rows:
  for peer in row.get('peers',[]):
   try:
    if not peer.get('valid'):raise ValueError(peer.get('error','invalid sample'))
    v=decode(peer,margin);groups[(v['server'],v['boot'],v.get('clocksource','unrecorded'))].append(v)
   except (ValueError,KeyError,TypeError,decimal.InvalidOperation)as e:errors.append({'seq':row.get('seq'),'server':peer.get('server'),'error':str(e)})
 out={'samples':len(rows),'seq':[v.get('seq')for v in rows],'errors':errors,'epochs':[],'utc_accuracy':'not measured','conditional_allowances_seconds':{'local':local,'server_margin':margin}}
 for (server,boot,source),good in groups.items():
  entry={'server':server,'boot':boot,'clocksource':source,'accepted':len(good),'windows':{}}
  if len(good)>=2:
   middle=len(good)//2
   windows={'whole':(good[0],good[-1])}
   if len(good)>=3:windows.update(first_half=(good[0],good[middle]),second_half=(good[middle],good[-1]))
   for name,(a,b)in windows.items():
    try:entry['windows'][name]={'ppm':estimate(a,b,local),'seconds':float(b['raw_lo']-a['raw_hi'])}
    except ValueError as e:entry['windows'][name]={'error':str(e)}
  out['epochs'].append(entry)
 return out

def test():
 rng=random.Random(314159)
 for _ in range(1000):
  rate=rng.uniform(-100,100);duration=rng.uniform(60,86400);e1=rng.uniform(0,.02);e2=rng.uniform(0,.02)
  a=dict(boot='one',server='one',server_time=1000+rng.uniform(-e1,e1),server_error=e1,raw_lo=100-rng.uniform(0,.2),raw_hi=100+rng.uniform(0,.2))
  raw=100+duration*(1+rate/1e6)
  b=dict(a,server_time=1000+duration+rng.uniform(-e2,e2),server_error=e2,raw_lo=raw-rng.uniform(0,.2),raw_hi=raw+rng.uniform(0,.2))
  lo,hi=estimate(a,b);assert lo<=rate<=hi
 for field in ('boot','server','clocksource'):
  bad=dict(b);bad[field]='different'
  try:estimate(a,bad)
  except ValueError:pass
  else:raise AssertionError(field)
 try:decode({'request':bytes(48).hex(),'response':bytes(48).hex()})
 except ValueError:pass
 else:raise AssertionError('invalid packet accepted')
 print('PASS 1000 asymmetric cases, source/epoch separation, invalid packet')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path,nargs='?');p.add_argument('--self-test',action='store_true');p.add_argument('--local',default='0.000010');p.add_argument('--server-margin',default='0.001');a=p.parse_args()
 if a.self_test:test()
 elif a.input:
  rows=[json.loads(line)for line in a.input.read_text().splitlines()];print(json.dumps(report(rows,a.local,a.server_margin),indent=2))
 else:p.error('input or --self-test required')
