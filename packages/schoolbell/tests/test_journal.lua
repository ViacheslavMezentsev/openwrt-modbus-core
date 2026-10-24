local M=require('schoolbell.journal')
local function fixture(original,fail)
 local files={};for k,v in pairs(original or {})do files[k]=v end
 local n=0;local function step()n=n+1;if n==fail then error('injected failure')end end
 local fs={}
 function fs.read(p,max)local s=files[p];assert(not s or #s<=max);return s end
 function fs.stat(p)return files[p] and {size=#files[p]}end
 function fs.write(p,v)step();assert(not files[p]);files[p]=v end
 function fs.sync()step()end
 function fs.rename(a,b)step();assert(files[a]);files[b]=files[a];files[a]=nil end
 function fs.unlink(p)step();files[p]=nil end
 function fs.space()return 1024*1024 end
 return fs,files
end
local fs,files=fixture()
for i=1,400 do M.append(fs,'save_ok',1700000000+i) end
local rows,last=M.read(fs);assert(last==400 and #rows>1 and #rows<400)
for _,p in ipairs({'journal-current.jsonl','journal-previous.jsonl'})do assert(files[p] and #files[p]<=8192)end
assert(not files['journal-next.tmp'])
M.append(fs,'storage_error',1600000000);rows,last=M.read(fs);assert(last==401 and rows[#rows].source=='system')
print('PASS journal: bounded rotation, sequential order despite clock rollback, source classes')
local before=files['journal-current.jsonl'];assert(not pcall(M.append,fs,string.rep('x',500),1700000000));assert(files['journal-current.jsonl']==before)
local bad,badfiles=fixture({['journal-current.jsonl']=string.rep('x',8193)});assert(not pcall(M.append,bad,'save_ok',1700000000));assert(#badfiles['journal-current.jsonl']==8193)
print('PASS journal: invalid/oversized input rejected without replacing evidence')
-- Build a nearly full current segment so the next append rotates.
local seed,base=fixture()
while true do
 local current=base['journal-current.jsonl'] or ''
 if #current>8070 then break end
 M.append(seed,'save_ok',1700000000)
end
for crash=1,6 do
 local f,storage=fixture(base,crash);pcall(M.append,f,'installed',1700000001)
 local recovered=fixture(storage);
 local oldrows,oldlast=M.read(recovered);assert(#oldrows>0)
 M.append(recovered,'save_ok',1700000002);local after,seq=M.read(recovered);assert(seq==oldlast+1 and #after>0)
end
print('PASS journal: recovery after every rotation write/sync/rename interruption')
local low,lowfiles=fixture();low.space=function()return 65536 end
assert(not pcall(M.append,low,'save_ok',1700000000));assert(not lowfiles['journal-current.jsonl'])
print('PASS journal: free-space reserve, no forced writes')
