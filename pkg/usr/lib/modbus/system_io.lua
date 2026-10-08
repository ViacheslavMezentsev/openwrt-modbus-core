local M = {}

function M.new(unit, handlers, publish, observe, clock)
    local previous, online
    local prefix = '/devices/' .. unit .. '/system/'
    local self = {}
    function self:invalidate(err)
        previous = nil
        handlers:discard()
        if online ~= false then
            publish({kind='system_button',unit=unit,valid=false,error=err})
            publish({kind='system_led',unit=unit,valid=false,error=err})
        end
        online = false
    end
    function self:step(port)
        local regs, err = port:read(unit, 4, 256, 8)
        if not regs then self:invalidate(err); return nil, err end
        if regs[1] ~= 0x5741 or regs[2] ~= 2 or regs[3] ~= 3 then
            err = 'unsupported system register map'
            self:invalidate(err); return nil, err
        end
        local coils
        coils, err = port:read(unit, 1, 256, 1)
        if not coils then self:invalidate(err); return nil, err end
        local current = {pressed=regs[4] == 1,count=regs[5]*65536+regs[6],
            uptime=regs[7]*65536+regs[8],led=coils[1] == 1}
        local delta = 0
        local baseline = previous == nil
        if previous then
            local dt = (current.uptime - previous.uptime) % 4294967296
            delta = (current.count - previous.count) % 4294967296
            -- Reject resets/discontinuities instead of replaying a huge counter delta.
            if dt > 60000 or delta > math.floor(dt / 60) + 1 then
                baseline, delta = true, 0
            end
        end
        local led = {kind='system_led',unit=unit,valid=true,value=current.led,baseline=baseline}
        if baseline or current.led ~= previous.led then publish(led)
        else observe(prefix .. 'led', led) end
        local button = {kind='system_button',unit=unit,valid=true,value=current.pressed,
            count=current.count,uptime_ms=current.uptime,presses_delta=delta,baseline=baseline}
        if baseline or delta > 0 or current.pressed ~= previous.pressed then publish(button)
        else observe(prefix .. 'button', button) end
        previous, online = current, true
        for _, command in ipairs(handlers:take()) do
            local ok, why
            if clock() - command.at > 1 then why = 'command expired'
            else
                ok, why = port:write_coil(unit, 256, command.value)
                if ok then
                    local readback
                    readback, why = port:read(unit, 1, 256, 1)
                    ok = readback and (readback[1] == (command.value and 1 or 0))
                    if not ok then why = why or 'LED readback mismatch' end
                end
            end
            publish({kind='command_result',unit=unit,handler=command.handler,
                target=command.topic,value=command.value,success=not not ok,error=why})
            if not ok then self:invalidate(why); return nil, why end
            current.led = command.value
            publish({kind='system_led',unit=unit,valid=true,value=current.led,baseline=false})
        end
        return current
    end
    return self
end

return M
