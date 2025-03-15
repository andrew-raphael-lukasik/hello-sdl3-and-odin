package main

import sdl "vendor:sdl3"
import "base:runtime"
import "core:log"
import "core:time"
import "core:math"
import "core:math/linalg"

vert_shader_spv := #load("../shaders_compiled/shader.spv.vert")
frag_shader_spv := #load("../shaders_compiled/shader.spv.frag")

main :: proc ()
{
    context.logger = log.create_console_logger()

    sdl.SetLogPriorities(.VERBOSE)
    
    ok := sdl.Init({.VIDEO})
    assert( ok )
    
    window_width: i32 = 1280
    window_height: i32 = 780
    window := sdl.CreateWindow("Hello SDL3 and Odin", window_width, window_height, {})
    assert( window!=nil )

    gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert( gpu!=nil )

    ok = sdl.ClaimWindowForGPUDevice(gpu, window)
    assert( ok )

    vert_shader := load_shader(gpu, vert_shader_spv, .VERTEX, 1)
    frag_shader := load_shader(gpu, frag_shader_spv, .FRAGMENT, 0)

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

    sdl.GetWindowSize(window, &window_width, &window_height)
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_width)/f32(window_width), 0.001, 1000.0 )
    model_matrix := linalg.MATRIX4F32_IDENTITY

    game_time_start := time.now()
    game_time_update: f64 = 0;
    // num_ticks := sdl.GetTicks()

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
        game_time_update = time.duration_seconds(time.since(game_time_start))
        model_matrix = linalg.matrix4_rotate_f32(f32(linalg.TAU)*f32(game_time_update), linalg.Vector3f32{0,1,0})
        model_matrix[3][0] = 0
        model_matrix[3][1] = 0
        model_matrix[3][2] = -10
 

        // RENDER
        cmd_buf := sdl.AcquireGPUCommandBuffer( gpu )

        swapchain_tex : ^sdl.GPUTexture
        ok = sdl.WaitAndAcquireGPUSwapchainTexture( cmd_buf , window , &swapchain_tex , nil , nil )
        assert( ok )

        if swapchain_tex!=nil
        {
            color_target := sdl.GPUColorTargetInfo {
                texture = swapchain_tex ,
                load_op = .CLEAR ,
                clear_color = { 0.2 , 0.2 , 0.2 , 1 } ,
                store_op = .STORE ,
            }

            render_pass := sdl.BeginGPURenderPass( cmd_buf , &color_target , 1 , nil )
            {
                sdl.BindGPUGraphicsPipeline(render_pass, pipeline);

                ubo := UBO{
                    mvp = proj_matrix * model_matrix
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

                // bind vertex data here
                // bind uniform data here

                sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
            }
            sdl.EndGPURenderPass( render_pass )
        }
        else
        {
            // not rendering, window minimized etc.
        }

        ok = sdl.SubmitGPUCommandBuffer( cmd_buf )
        assert( ok )
    }
}

load_shader :: proc (device: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32) -> ^sdl.GPUShader
{
    return sdl.CreateGPUShader(device, {
        code_size = len(code),
        code = raw_data(code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = stage,
        num_uniform_buffers = num_uniform_buffers,
    })
}

UBO :: struct {
    mvp: matrix[4,4]f32
}
