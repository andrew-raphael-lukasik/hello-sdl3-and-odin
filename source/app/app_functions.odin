package app
import "core:time"
import win "core:sys/windows"
import "core:os"
import "core:path/filepath"
import "core:mem"
import "core:mem/virtual"
import "core:strings"
import "core:log"
import "base:runtime"
import "../steam"


init :: proc () -> runtime.Context
{
    when ODIN_DEBUG
    {
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        default_allocator = context.allocator
        context.allocator = mem.tracking_allocator((&tracking_allocator))
    }

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

    arena_buffer = make([]byte, 1024*1024)
    {
        arena_init_error := virtual.arena_init_buffer(&arena, arena_buffer)
        if arena_init_error!=nil { log.panicf("Error initializing arena: %v\n", arena_init_error) }
        arena_allocator = virtual.arena_allocator(&arena)
    }

    app_context = context
    return app_context
}

close :: proc ()
{
    virtual.arena_free_all(&arena)
    delete(arena_buffer)
    delete(dir_current)
    delete(dir_parent)
    
    steam.close()

    when ODIN_DEBUG
    {
        for key, value in tracking_allocator.allocation_map { log.errorf("%v: Leaked %v bytes\n", value.location, value.size) }
        for value in tracking_allocator.bad_free_array { log.errorf("Bad free at: %v\n", value.location) }
    }
}

tick :: proc ()
{
    time_tick = time.duration_seconds(time.since(time_start))

    steam.tick()
}


num_bytes_of :: proc (source: ^[]$E) -> int { return len(source) * size_of(source[0]) }
num_bytes_of_u32 :: proc (source: ^[]$E) -> u32 { return u32(num_bytes_of(source)) }

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
