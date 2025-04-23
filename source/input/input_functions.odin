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
    move = {0, 0}
    mouse_move = {0, 0}
    clear(&key_up)
    clear(&mouse_up)
    
    ev: sdl.Event
    for sdl.PollEvent(&ev)
    {
        keycode := ev.key.scancode
        #partial switch ev.type
        {
            case .QUIT:
                app.alive = 0
            
            // KEYBOARD
            case .KEY_DOWN:
                key_down[ev.key.scancode] = true
                
                if keycode==.ESCAPE do app.alive = 0
                
                if keycode==.LEFT do move[0] -= 1
                if keycode==.RIGHT do move[0] += 1
                if keycode==.DOWN do move[1] -= 1
                if keycode==.UP do move[1] += 1
            case .KEY_UP:
                key_down[ev.key.scancode] = false
                key_up[ev.key.scancode] = true
            
            // MOUSE
            case .MOUSE_MOTION:
                mouse_move[0] = ev.motion.xrel
                mouse_move[1] = ev.motion.yrel
            case .MOUSE_BUTTON_DOWN:
                mouse_down[ev.button.button] = true
            case .MOUSE_BUTTON_UP:
                mouse_down[ev.button.button] = false
                mouse_up[ev.button.button] = true
        }
    }

    when INPUT_DEBUG{
        for scancode in sdl.Scancode {
            if key_down[scancode] do log.debugf("input.key_down[{}]", scancode)
            if key_up[scancode] do log.debugf("input.key_up[{}]", scancode)
        }
        for i:u8=0 ; i<255 ; i+=1 {
            if mouse_down[i] do log.debugf("input.mouse_down[{}]", i)
            if mouse_up[i] do log.debugf("input.mouse_up[{}]", i)
        }
    }
}
