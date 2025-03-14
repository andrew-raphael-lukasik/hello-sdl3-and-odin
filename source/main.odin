package main

import "base:runtime"
import "core:log"
import sdl "vendor:sdl3"

vert_shader_spv := #load("../shaders_compiled/shader.spv.vert")
frag_shader_spv := #load("../shaders_compiled/shader.spv.frag")

main :: proc ()
{
    context.logger = log.create_console_logger()

    sdl.SetLogPriorities(.VERBOSE)
    
    ok := sdl.Init({.VIDEO})
    assert( ok )
    
    window := sdl.CreateWindow("Hello SDL3 and Odin", 1280, 780, {})
    assert( window!=nil )

    main_loop: for
    {
        ev: sdl.Event
        for sdl.PollEvent(&ev)
        {
            #partial switch ev.type
            {
                case .QUIT: break main_loop
                case .KEY_DOWN: if ev.key.scancode==.ESCAPE do break main_loop
            }
        }
    }
}
