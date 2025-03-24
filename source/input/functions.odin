package input
import sdl "vendor:sdl3"
import "core:fmt"
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
        #partial switch ev.type
        {
            case .QUIT: app.alive = 0
            case .KEY_DOWN: if ev.key.scancode==.ESCAPE do app.alive = 0
        }
    }
}
