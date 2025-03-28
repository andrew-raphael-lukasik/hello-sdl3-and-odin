package app
import "core:time"
import win "core:sys/windows"
import "core:os"
import "core:path/filepath"
import "core:mem"
import "core:strings"
import "../steam"


init :: proc ()
{
    alive = 1;
    time_start = time.now()
    // num_ticks = sdl.GetTicks()
    // win.LoadLibraryW()

    dir_current = os.get_current_directory()
    dir_parent = filepath.dir(dir_current)

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


num_bytes_of :: proc (source: ^[]$E) -> int { return len(source) * size_of(source[0]) }

path_to_abs :: proc (path_relative: string, allocator: mem.Allocator = context.allocator) -> (path_abs: string)
{
    return filepath.join([]string{dir_parent, path_relative}, allocator)
}
path_to_abs_c :: proc (path_relative: string, allocator: mem.Allocator = context.allocator) -> (path_abs: cstring)
{
    str := path_to_abs(path_relative, allocator)
    cstr := strings.clone_to_cstring(str, allocator)
    delete(str)
    return cstr
}
path_to_rel :: proc (path_abs: string, allocator: mem.Allocator = context.allocator) -> (path_relative: string)
{
    NOT_IMPLEMENTED :: "NOT IMPLEMENTED"
    assert(false, NOT_IMPLEMENTED)
    return NOT_IMPLEMENTED
}
path_to_rel_c :: proc (path_abs: string, allocator: mem.Allocator = context.allocator) -> (path_relative: string)
{
    NOT_IMPLEMENTED :: "NOT IMPLEMENTED"
    assert(false, NOT_IMPLEMENTED)
    return NOT_IMPLEMENTED
}
