local prefix = '/devices/' .. UNIT_ID .. '/system/'
return {
    topic = prefix .. 'button',
    handle = function(event, ctx)
        if not event.valid or event.baseline or (event.presses_delta or 0) % 2 == 0 then return end
        local led = ctx.get(prefix .. 'led')
        if led and led.valid and led.age <= 1 then
            ctx.set(prefix .. 'led', not led.value)
        end
    end
}
