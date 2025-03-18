package main

import sdl "vendor:sdl3"
// import "base:runtime"
import "core:log"
import "core:time"
// import "core:math"
import "core:mem"
import "core:math/linalg"

vert_shader_spv := #load("../shaders_compiled/shader.spv.vert")
frag_shader_spv := #load("../shaders_compiled/shader.spv.frag")

Vertex_Data :: struct
{
    pos: [3]f32,
    col: [3]f32,
}

vertex_data_trianle : []Vertex_Data = {
    { pos = {-0.9, -0.9, 0}, col = {1, 1, 0} },
    { pos = {0, 0.9, 0}, col = {0, 1, 1} },
    { pos = {0.9, -0.9, 0}, col = {1, 0, 1} },
}
trianle_vertex_data_num_bytes := u32(len(vertex_data_trianle) * size_of(vertex_data_trianle[0]))

main :: proc ()
{
    context.logger = log.create_console_logger()
    sdl.SetLogPriorities(.VERBOSE)

    // log.debugf("trianle_num_bytes: {}", trianle_num_bytes)
    
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

    vertex_buffer_gpu := sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.VERTEX },
        size =  trianle_vertex_data_num_bytes,
    })
    vertex_transfer_buf := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo{
        usage = sdl.GPUTransferBufferUsage.UPLOAD,
        size = trianle_vertex_data_num_bytes,
        props = 0,
    })
    {
        vertex_transfer_map := sdl.MapGPUTransferBuffer(gpu, vertex_transfer_buf, false)
        mem.copy(vertex_transfer_map, raw_data(vertex_data_trianle), int(trianle_vertex_data_num_bytes))
        sdl.UnmapGPUTransferBuffer(gpu, vertex_transfer_buf)
    }

    copy_cmd_buf := sdl.AcquireGPUCommandBuffer( gpu )
    {
        copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
        sdl.UploadToGPUBuffer(
            copy_pass,
            sdl.GPUTransferBufferLocation{
                transfer_buffer = vertex_transfer_buf,
                offset = 0,
            },
            sdl.GPUBufferRegion{
                buffer = vertex_buffer_gpu,
                offset = 0,
                size = trianle_vertex_data_num_bytes,
            },
            false
        )
        sdl.EndGPUCopyPass(copy_pass)
    }
    ok = sdl.SubmitGPUCommandBuffer( copy_cmd_buf )
    assert( ok )
    sdl.ReleaseGPUTransferBuffer(gpu, vertex_transfer_buf)

    vert_attrs := []sdl.GPUVertexAttribute{
        {
            location = 0,
            buffer_slot = 0,
            format = .FLOAT3,
            offset = u32(offset_of(Vertex_Data, pos)),
        },
        {
            location = 1,
            buffer_slot = 0,
            format = .FLOAT3,
            offset = u32(offset_of(Vertex_Data, col)),
        },
    }
    pipeline := sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription{
                slot = 0,
                pitch = size_of(Vertex_Data),
                input_rate = .VERTEX,
            },
            num_vertex_buffers = 1,
            vertex_attributes = raw_data(vert_attrs),
            num_vertex_attributes = u32(len(vert_attrs)),
        },
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

                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer=vertex_buffer_gpu, offset=0}, 1)

                ubo := UBO{
                    mvp = proj_matrix * model_matrix
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

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
