-- Fixed-sample commissioning tool, not the production queue/player adapter.
local M = {}
M.sample = "/usr/share/schoolbell-sound-test/test.mp3"
M.lock = "/tmp/schoolbell-sound-test.lock"
function M.run(io)
    if not io.ready() then return {ok=false, state="unavailable"} end
    if not io.acquire() then return {ok=false, state="busy"} end
    local pid = io.spawn()
    local function finish(state, ok, code)
        if not io.release() then return {ok=false, state="cleanup_required"} end
        return {ok=ok, state=state, exit_code=code}
    end
    if not pid then return finish("spawn_failed", false) end
    for i=1,100 do
        local p, why, code = io.wait(pid)
        if p == pid then
            return finish(why == "exited" and code == 0 and "completed" or "failed",
                          why == "exited" and code == 0, code)
        end
        -- nil means an uncertain wait error; false means still running.
        if p == nil then return {ok=false, state="recovery_required"} end
        io.sleep()
    end
    io.kill(pid)
    for i=1,20 do
        local p = io.wait(pid)
        if p == pid then return finish("timeout", false) end
        if p == nil then break end
        io.sleep()
    end
    -- Never unlock when the child outcome is unknown.
    return {ok=false, state="recovery_required"}
end
function M.system()
    local n, fs = require("nixio"), require("nixio.fs")
    return {
        ready=function()
            local s=fs.lstat(M.sample)
            return s and s.type=="reg" and s.size==13104
                and fs.access("/usr/bin/madplay","x") and fs.access("/dev/dsp","w")
        end,
        acquire=function() return fs.mkdir(M.lock,700) end,
        release=function() return fs.rmdir(M.lock) end,
        spawn=function()
            local pid=n.fork()
            if pid==0 then
                local f=n.open("/dev/null","r+")
                if not f then os.exit(126) end
                if not n.dup(f,n.stdin) or not n.dup(f,n.stdout) or not n.dup(f,n.stderr) then os.exit(126) end
                f:close()
                n.exec("/usr/bin/madplay","--no-tty-control","-a","0","-R","48000",
                       "-o","/dev/dsp",M.sample)
                os.exit(127)
            end
            return pid
        end,
        wait=function(pid) return n.waitpid(pid,"nohang") end,
        sleep=function() n.nanosleep(0,100000000) end,
        kill=function(pid) return n.kill(pid,9) end
    }
end
return M
