-- Optional native Linux/nixio integration; fixtures supplied by Python harness.
package.path="./pkg/usr/lib/?.lua;"..package.path
local adapter=require("modbus.profile_reader")
local n=require("nixio")
local fs=require("nixio.fs")
local api={uname=n.uname,open=n.open,open_flags=n.open_flags,fs=fs}
local base=assert(arg[1])
local function read(root,id) return assert(adapter.new(api,root))(id or "p",16385) end
assert(read(base.."/good")=='{"id":"p","read_ranges":[{"function":3,"start":0,"count":1}]}')
assert(#assert(read(base.."/exact"))==16384)
for _,name in ipairs({"oversize","symlink","fifo","hardlink","writable","foreign","directory","missing","linkdir","weakdir"}) do
    local data,err=read(base.."/"..name)
    assert(not data and err, name)
end
-- Deterministic replacement at the real syscall boundary.
for _,kind in ipairs({"racereg","racesymlink","raceread"}) do
    local swapped=false
    local function swap()
        assert(fs.rename(base.."/"..kind.."/replacement",base.."/"..kind.."/p.json"))
        swapped=true
    end
    local wrapped={uname=n.uname,open_flags=n.open_flags,fs=fs}
    wrapped.open=function(path,flags)
        local file=path:match("/p.json$")
        if file and kind~="raceread" then swap() end
        local fd=n.open(path,flags)
        if not fd or not file or kind~="raceread" then return fd end
        return {
            stat=function() return fd:stat() end,
            fileno=function() return fd:fileno() end,
            close=function() return fd:close() end,
            read=function(_,size)
                local data=fd:read(size)
                if not swapped then swap() end
                return data
            end
        }
    end
    local data,err=assert(adapter.new(wrapped,base.."/"..kind))("p",16385)
    assert(swapped and not data and err,kind)
end
local before=0
for _ in fs.dir("/proc/self/fd") do before=before+1 end
for i=1,100 do assert(read(base.."/good"));assert(not read(base.."/fifo")) end
local after=0
for _ in fs.dir("/proc/self/fd") do after=after+1 end
assert(before==after,"native descriptor leak")
print("[profile-reader-native] OK: real nixio files/modes/symlinks/FIFO/hardlinks/size, 3 replacement races and 200-read FD stability")
