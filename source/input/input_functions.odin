package input
import sdl "vendor:sdl3"
import "core:log"
import "../app"


INPUT_DEBUG :: #config(INPUT_DEBUG, false)

init :: proc ()
{

}

close :: proc ()
{

}

tick :: proc ()
{
    action_mouse_move = {0, 0}
    clear(&key_up)
    clear(&mouse_up)
    
    ev: sdl.Event
    for sdl.PollEvent(&ev) {
        keycode := ev.key.scancode
        #partial switch ev.type {
            case .QUIT:
                app.alive = false
            
            // KEYBOARD
            case .KEY_DOWN:
                key_down[ev.key.scancode] = true
                if ev.key.scancode==.ESCAPE do app.alive = false
            case .KEY_UP:
                key_down[ev.key.scancode] = false
                key_up[ev.key.scancode] = true
            
            // MOUSE
            case .MOUSE_MOTION:
                action_mouse_move.x = ev.motion.xrel
                action_mouse_move.y = ev.motion.yrel
            case .MOUSE_BUTTON_DOWN:
                mouse_down[ev.button.button] = true
            case .MOUSE_BUTTON_UP:
                mouse_down[ev.button.button] = false
                mouse_up[ev.button.button] = true
        }

        action_move = {
            ((key_down[.LEFT] || key_down[.A]) ? -1 : 0) + ((key_down[.RIGHT] || key_down[.D]) ? 1 : 0),
            ((key_down[.DOWN] || key_down[.S]) ? -1 : 0) + ((key_down[.UP] || key_down[.W]) ? 1 : 0),
        }
        action_jump = key_down[.SPACE] ? 1 : 0
        action_crouch = (key_down[.LCTRL] || key_down[.RCTRL]) ? 1 : 0
    }

    when INPUT_DEBUG
    {
        for scancode in sdl.Scancode {
            if key_down[scancode] do log.debugf("input.key_down[{}]", scancode)
            if key_up[scancode] do log.debugf("input.key_up[{}]", scancode)
        }
        for i in 0..<255 {
            if mouse_down[i] do log.debugf("input.mouse_down[{}]", i)
            if mouse_up[i] do log.debugf("input.mouse_up[{}]", i)
        }
    }
}
