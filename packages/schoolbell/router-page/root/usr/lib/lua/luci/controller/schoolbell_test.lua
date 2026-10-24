module("luci.controller.schoolbell_test", package.seeall)
function index()
    local page=entry({"admin","schoolbell"},call("page"),"Schoolbell",70)
    page.dependent=false
    entry({"admin","schoolbell","sample"},call("sample")).leaf=true
    entry({"admin","schoolbell","play"},call("play")).leaf=true
end
function page()
    local d=require("luci.dispatcher")
    require("luci.http").header("Cache-Control","no-store")
    require("luci.template").render("schoolbell_test",{
        play_url=d.build_url("admin","schoolbell","play"),
        sample_url=d.build_url("admin","schoolbell","sample"),
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
