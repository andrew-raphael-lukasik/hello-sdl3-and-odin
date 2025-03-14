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

    gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert( gpu!=nil )

    ok = sdl.ClaimWindowForGPUDevice(gpu, window)
    assert( ok )

    vert_shader := load_shader(gpu, vert_shader_spv, .VERTEX)
    frag_shader := load_shader(gpu, frag_shader_spv, .FRAGMENT)

    pipeline := sdl.CreateGPUGraphicsPipeline(gpu ,{
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription{
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window)
            })
        }
    } )

    sdl.ReleaseGPUShader(gpu, vert_shader)
    sdl.ReleaseGPUShader(gpu, frag_shader)

    main_loop: for
    {
        // PROCESS EVENTS
        ev: sdl.Event
        for sdl.PollEvent(&ev)
        {
            #partial switch ev.type
            {
                case .QUIT: break main_loop
                case .KEY_DOWN: if ev.key.scancode==.ESCAPE do break main_loop
            }
        }


        // UPDATE GAME STATE


        // RENDER
        cmd_buf := sdl.AcquireGPUCommandBuffer( gpu )

        swapchain_tex : ^sdl.GPUTexture
        ok = sdl.WaitAndAcquireGPUSwapchainTexture( cmd_buf , window , &swapchain_tex , nil , nil )
        assert( ok )

        color_target := sdl.GPUColorTargetInfo {
            texture = swapchain_tex ,
            load_op = .CLEAR ,
            clear_color = { 0.2 , 0.2 , 0.2 , 1 } ,
            store_op = .STORE ,
        }

        render_pass := sdl.BeginGPURenderPass( cmd_buf , &color_target , 1 , nil )
        {
            sdl.BindGPUGraphicsPipeline(render_pass, pipeline);

            // bind vertex data here
            // bind uniform data here

            sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
        }
        sdl.EndGPURenderPass( render_pass )

        ok = sdl.SubmitGPUCommandBuffer( cmd_buf )
        assert( ok )
    }
}

load_shader :: proc (device: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage) -> ^sdl.GPUShader
{
    return sdl.CreateGPUShader(device, {
        code_size = len(code),
        code = raw_data(code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = stage
    })
}
