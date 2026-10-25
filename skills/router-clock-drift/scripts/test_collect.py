#!/usr/bin/env python3
"""Exercise collector orchestration with fake SSH, DNS and clocks; no network."""
import contextlib, io, json, struct, sys, tempfile
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
import collect

def main():
 req=bytearray(48);req[0]=0x23;struct.pack_into('!II',req,40,3998988800,0)
 response=bytearray(48);response[0]=0x24;response[1]=2;response[3]=(-20)&255;response[24:32]=req[40:48];struct.pack_into('!II',response,32,3998988800,0);struct.pack_into('!II',response,40,3998988800,0)
 value={'boot':'synthetic','clocksource':'synthetic','raw_lo':100,'raw_hi':100.01,'request':req.hex(),'response':response.hex()}
 clock=[0.0];calls=[]
 def run(args,**kwargs):
  calls.append(args)
  if args[-1].startswith('sha256sum '):return SimpleNamespace(returncode=0,stdout='a'*64+'  probe',stderr='')
  return SimpleNamespace(returncode=0,stdout=json.dumps(value),stderr='')
 with tempfile.TemporaryDirectory()as tmp:
  output=Path(tmp)/'run'
  args=['collect.py','--host','synthetic','--probe','/tmp/test/probe','--sha256','a'*64,'--server','ref-a','--server','ref-b','--interval','60','--samples','2','--out',str(output)]
  with patch.object(sys,'argv',args),patch.object(collect.subprocess,'run',run),patch.object(collect.socket,'gethostbyname',lambda _: '192.0.2.1'),patch.object(collect.time,'monotonic',lambda:clock[0]),patch.object(collect.time,'sleep',lambda v:clock.__setitem__(0,clock[0]+v)),contextlib.redirect_stdout(io.StringIO()):
   collect.main();status=json.loads((output/'status.json').read_text());assert status['state']=='complete' and status['ok']
   rows=[json.loads(x)for x in (output/'samples.jsonl').read_text().splitlines()];assert [x['seq']for x in rows]==[0,1] and len(calls)==5
   try:collect.main()
   except FileExistsError:pass
   else:raise AssertionError('restarted completed experiment')
   assert len(calls)==5
 print('PASS collector: fake SSH/DNS/clock, two peers, expected seq/status, refusal to restart')
if __name__=='__main__':main()
