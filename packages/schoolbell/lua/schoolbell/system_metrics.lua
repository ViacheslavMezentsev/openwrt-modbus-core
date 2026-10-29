local M={}
function M.parse(line)
 if type(line)~='string' or not line:match('^cpu%s')then return {available=false}end
 local fields={};for v in line:gmatch('%d+')do fields[#fields+1]=tonumber(v)end
 if #fields<4 then return {available=false}end
 local total=0;for i=1,math.min(8,#fields)do total=total+fields[i]end -- guest already included in user/nice
 if total>9007199254740991 then return {available=false}end
 return {available=true,total=string.format('%.0f',total),idle=string.format('%.0f',fields[4]+(fields[5] or 0))}
end
function M.uptime(line)
 if type(line)~='string' then return nil end
 local value=tonumber(line:match('^(%d+%.?%d*)%s'))
 if not value or value<0 or value>9007199254740991 then return nil end
 return math.floor(value)
end
function M.read()
 local ok,v=pcall(function()
  local f=assert(io.open('/proc/stat','r'));local line=f:read('*l');f:close();local s=M.parse(line)
  local f=assert(io.open('/proc/sys/kernel/random/boot_id','r'));s.boot=f:read(64);f:close()
  local f=io.open('/proc/uptime','r');if f then s.uptime_seconds=M.uptime(f:read(128));f:close()end
  return s
 end)
 return ok and v or {available=false}
end
return M
