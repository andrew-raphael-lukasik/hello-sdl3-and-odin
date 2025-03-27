package main
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "base:runtime"
import "core:debug/trace"
import "render"
import "input"
import "app"
import "game"


default_assertion_failure_proc: runtime.Assertion_Failure_Proc


main :: proc ()
{
    when ODIN_DEBUG
    {
        default_assertion_failure_proc = context.assertion_failure_proc
        context.assertion_failure_proc = on_assertion_failure

        logger := log.create_console_logger()
        context.logger = logger
        {
            dir_current := os.get_current_directory(context.temp_allocator)
            path := filepath.join([]string{dir_current, "log.txt"}, context.temp_allocator)
            log_file_handle, err := os.open(path, os.O_CREATE | os.O_TRUNC | os.O_WRONLY)
            if err==nil
            {
                log.debugf("Log file path: {}", path)
                file_logger := log.create_file_logger(log_file_handle)
                multi_logger := log.create_multi_logger(logger, file_logger)
                logger = multi_logger
            }
            else do log.errorf("'{}' error while creating log file at path: {}", err, path)
        }
        context.logger = logger
        log.debugf("Application started")
    }

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
    
    app.init()
    game.init()
    input.init()
    render.init()

    for app.alive!=0
    {
        app.tick()
        input.tick()
        game.tick()
        render.tick()
    }

    game.close()
    input.close()
    app.close()
    render.close()

    delete(arena_buffer)

    when ODIN_DEBUG
    {
        for key, value in tracking_allocator.allocation_map { log.errorf("%v: Leaked %v bytes\n", value.location, value.size) }
        for value in tracking_allocator.bad_free_array { log.errorf("Bad free at: %v\n", value.location) }
    }
}

// readme: https://pkg.odin-lang.org/core/debug/trace/
on_assertion_failure :: proc(prefix, message: string, loc := #caller_location) -> !
{
    log.errorf("Asserion '{}' failed, loc: {}", message, loc)
    default_assertion_failure_proc(prefix, message,loc)
    // runtime.trap()
}
