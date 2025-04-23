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
    action_move = {0, 0}
    action_mouse_move = {0, 0}
    action_jump = 0
    action_crouch = 0
    clear(&key_up)
    clear(&mouse_up)
    
    ev: sdl.Event
    for sdl.PollEvent(&ev) {
        keycode := ev.key.scancode
        #partial switch ev.type {
            case .QUIT:
                app.alive = 0
            
            // KEYBOARD
            case .KEY_DOWN:
                key_down[ev.key.scancode] = true
                #partial switch keycode
                {
                    case .ESCAPE: app.alive = 0
                    case .LEFT, .A: action_move[0] -= 1
                    case .RIGHT, .D: action_move[0] += 1
                    case .DOWN, .S: action_move[1] -= 1
                    case .UP, .W: action_move[1] += 1
                    case .SPACE: action_jump = 1
                    case .LCTRL, .RCTRL: action_crouch = 1
                }
            case .KEY_UP:
                key_down[ev.key.scancode] = false
                key_up[ev.key.scancode] = true
            
            // MOUSE
            case .MOUSE_MOTION:
                action_mouse_move[0] = ev.motion.xrel
                action_mouse_move[1] = ev.motion.yrel
            case .MOUSE_BUTTON_DOWN:
                mouse_down[ev.button.button] = true
            case .MOUSE_BUTTON_UP:
                mouse_down[ev.button.button] = false
                mouse_up[ev.button.button] = true
        }
    }

    when INPUT_DEBUG
    {
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
