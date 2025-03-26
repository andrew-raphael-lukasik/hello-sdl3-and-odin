package app
import "core:time"
import "../steam"


init :: proc ()
{
    alive = 1;
    time_start = time.now()
    // num_ticks = sdl.GetTicks()

    steam.init()
    if steam.steam_init_termination_requested==1
    {
        alive = 0
    }
}

close :: proc ()
{
    steam.close()
}

tick :: proc ()
{
    time_tick = time.duration_seconds(time.since(time_start))

    steam.tick()
}
