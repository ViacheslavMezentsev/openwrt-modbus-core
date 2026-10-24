module("luci.controller.schoolbell_test", package.seeall)
function index()
    local page=entry({"admin","schoolbell"},call("page"),"Schoolbell",70)
    page.dependent=false
    entry({"admin","schoolbell","schedules"},call("schedules")).leaf=true
    entry({"admin","schoolbell","save-schedules"},call("save_schedules")).leaf=true
    entry({"admin","schoolbell","sample"},call("sample")).leaf=true
    entry({"admin","schoolbell","play"},call("play")).leaf=true
end
local function editor()
    -- Private bundled dependencies; installed core modules remain untouched.
    local path="/usr/share/schoolbell-editor/lua/?.lua;"
    if not package.path:find(path,1,true) then package.path=path..package.path end
    return require("schoolbell.schedule_store"),require("schoolbell.media_codec")
end
local function respond(result)
    local h=require("luci.http")
    h.header("Cache-Control","no-store")
    h.prepare_content("application/json")
    local _,codec=editor()
    h.write(codec.encode(result))
end
function schedules()
    if require("luci.http").getenv("REQUEST_METHOD")~="GET" then
        require("luci.http").status(405,"Method Not Allowed"); return
    end
    local store=editor()
    respond(store.request("/etc/schoolbell-editor","load"))
end
function save_schedules()
    local h=require("luci.http")
    -- Bound form decoding before requesting token/form values.
    local length=tonumber(h.getenv("CONTENT_LENGTH"))
    local content=h.getenv("CONTENT_TYPE") or ""
    if not length or length<1 or length>49152
       or not content:match("^application/x%-www%-form%-urlencoded") then
        h.status(413,"Unsupported or oversized request"); return
    end
    if not require("luci.dispatcher").test_post_security() then return end
    local store=editor()
    respond(store.request("/etc/schoolbell-editor","save",h.formvalue("draft"),h.formvalue("revision")))
end
function page()
    local d=require("luci.dispatcher")
    require("luci.http").header("Cache-Control","no-store")
    require("luci.template").render("schoolbell_test",{
        play_url=d.build_url("admin","schoolbell","play"),
        sample_url=d.build_url("admin","schoolbell","sample"),
        schedules_url=d.build_url("admin","schoolbell","schedules"),
        save_url=d.build_url("admin","schoolbell","save-schedules"),
        token=d.context.authtoken
    })
end
function sample()
    local h=require("luci.http")
    h.header("Cache-Control","no-store")
    local f=io.open(require("schoolbell.sound_test").sample,"rb")
    if not f then h.status(503,"Sample unavailable"); return end
    h.prepare_content("audio/mpeg")
    h.write(f:read("*a")); f:close()
end
function play()
    local h=require("luci.http")
    if not require("luci.dispatcher").test_post_security() then return end
    local m=require("schoolbell.sound_test")
    local ok,result=pcall(m.run,m.system())
    if not ok then result={ok=false,state="recovery_required"} end
    h.header("Cache-Control","no-store")
    h.prepare_content("application/json")
    h.write_json(result)
end
