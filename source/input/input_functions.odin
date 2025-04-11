package input
import sdl "vendor:sdl3"
import "core:log"
import "../app"


init :: proc ()
{
     
}

close :: proc ()
{

}

tick :: proc ()
{
    ev: sdl.Event
    for sdl.PollEvent(&ev)
    {
        move = {0, 0}

        keycode := ev.key.scancode
        #partial switch ev.type
        {
            case .QUIT:
                app.alive = 0
            case .KEY_DOWN:
                if keycode==.ESCAPE do app.alive = 0
                
                if keycode==.LEFT do move[0] -= 1
                if keycode==.RIGHT do move[0] += 1
                if keycode==.DOWN do move[1] -= 1
                if keycode==.UP do move[1] += 1
        }
    }
}
