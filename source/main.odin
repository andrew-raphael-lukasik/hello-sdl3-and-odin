package main
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "render"
import "input"
import "app"
import "game"


main :: proc ()
{
    default_allocator := context.allocator
    when ODIN_DEBUG
    {
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        context.allocator = mem.tracking_allocator((&tracking_allocator))
    }

    arena_allocator : mem.Allocator
    arena_buffer := make([]byte, 1024*1024)
    {
        arena: virtual.Arena
        arena_init_error := virtual.arena_init_buffer(&arena, arena_buffer)
        if arena_init_error!=nil { log.panicf("Error initializing arena: %v\n", arena_init_error) }
        arena_allocator = virtual.arena_allocator(&arena)
    }

    context.logger = log.create_console_logger(allocator = default_allocator)

    when ODIN_DEBUG
    {
        sdl.SetLogPriorities(.VERBOSE)
    }
    else
    {
        sdl.SetLogPriorities(.WARN)
    }
    
    app.init()
    render.init()
    input.init()
    game.init()

    for app.alive!=0
    {
        app.tick()
        input.tick()
        game.tick()
        render.tick()
    }

    input.close()
    render.close()
    game.close()
    app.close()

    delete(arena_buffer)

    when ODIN_DEBUG
    {
        for key, value in tracking_allocator.allocation_map { log.errorf("%v: Leaked %v bytes\n", value.location, value.size) }
        for value in tracking_allocator.bad_free_array { log.errorf("Bad free at: %v\n", value.location) }
    }
}
