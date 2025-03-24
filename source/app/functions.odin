package app
import "core:time"


init :: proc ()
{
    alive = 1;
    time_start = time.now()
    // num_ticks = sdl.GetTicks()
}

close :: proc ()
{

}

tick :: proc ()
{
    time_tick = time.duration_seconds(time.since(time_start))
}
