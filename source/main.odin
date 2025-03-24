package main

import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
// import "base:runtime"
import "core:log"
import "core:time"
import math "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:math/linalg"
import fmt "core:fmt"
import cgltf "vendor:cgltf"



num_bytes_of :: proc (source: ^[]$E) -> int { return len(source) * size_of(source[0]) }

vert_shader_spv := #load("../shaders_compiled/shader.spv.vert")
frag_shader_spv := #load("../shaders_compiled/shader.spv.frag")

Vertex_Data :: struct
{
    pos: [3]f32,
    col: [3]f32,
    uv: [2]f32
}

vertices : []Vertex_Data = {
    { pos = {-0.5, -0.5, 0}, col = {1, 1, 0}, uv = {0, 1}},//BL
    { pos = {-0.5, 0.5, 0}, col = {0, 1, 1}, uv = {0, 0}},//TL
    { pos = {0.5, 0.5, 0}, col = {1, 0, 1}, uv = {1, 0}},//TR
    { pos = {0.5, -0.5, 0}, col = {1, 1, 1}, uv = {1, 1}},//BR
}
vertices_num_bytes := u32(num_bytes_of(&vertices))
indices := []u16 {
    0, 1, 2,
    0, 2, 3,
}
indices_num_bytes := u32(num_bytes_of(&indices))

TransferBufferQueueItem :: struct
{
    transfer_buffer_offset: int,
    size: int,
    source: rawptr,
    gpu_buffer_region: ^sdl.GPUBufferRegion,
    gpu_texture_region: ^sdl.GPUTextureRegion,
}
transfer_buffer_queue := make([dynamic]TransferBufferQueueItem, 0, 32)
transfer_buffer_queue_append :: proc (source: ^[]$E, gpu_buffer_region: ^sdl.GPUBufferRegion, gpu_texture_region: ^sdl.GPUTextureRegion,)
{
    offset := 0
    {
        l := len(transfer_buffer_queue)
        if l!=0
        {
            offset = transfer_buffer_queue[l-1].transfer_buffer_offset + transfer_buffer_queue[l-1].size
        }
    }
    append(&transfer_buffer_queue, TransferBufferQueueItem{
        transfer_buffer_offset = offset,
        size = num_bytes_of(source),
        source = raw_data(source^),
        gpu_buffer_region = gpu_buffer_region,
        gpu_texture_region = gpu_texture_region,
    })
}



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

    sdl.SetLogPriorities(.VERBOSE)

    if !sdl.Init({.VIDEO}) {
        fmt.eprintln(sdl.GetError())
        return
    }
    defer sdl.Quit()
    
    window_width:i32 = 1280
    window_height:i32 = 780
    window := sdl.CreateWindow("Hello SDL3 and Odin", window_width, window_height, {})
    if window==nil {
        fmt.eprintln(sdl.GetError())
        return
    }
    defer sdl.DestroyWindow(window)

    gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert(gpu!=nil)

    ok := sdl.ClaimWindowForGPUDevice(gpu, window)
    assert(ok)

    vert_shader := load_shader(gpu, vert_shader_spv, .VERTEX, 1, 0)
    frag_shader := load_shader(gpu, frag_shader_spv, .FRAGMENT, 0, 1)

    // image := sdl_image.Load("checker")
    image_pixels := []u8{
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,
        
        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,

        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,

        255, 0, 0, 255,
        0, 255, 0, 255,
        0, 0, 255, 255,
        255, 255, 0, 255,
    }
    image := sdl.Surface{
        flags = { sdl.SurfaceFlag.PREALLOCATED },
        format = sdl.PixelFormat.RGBA32,
        w = 4,
        h = 4,
        pitch = 4*4,
        pixels = &image_pixels,//sdl.aligned_alloc(512,16),
        refcount = 0,
        reserved = nil,
    }
    texture := sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = sdl.GPUTextureFormat.R8G8B8A8_UNORM,
        usage = { sdl.GPUTextureUsageFlag.SAMPLER },
        width = 4,
        height = 4,
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    texture_buffer_gpu := sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.GRAPHICS_STORAGE_READ },
        size =  vertices_num_bytes,
    })
    transfer_buffer_queue_append(&image_pixels, nil, &sdl.GPUTextureRegion{
        texture = texture,
        mip_level = 0,
        layer = 0,
        x = 0,
        y = 0,
        z = 0,
        w = 4,
        h = 4,
        d = 1,
    })

    vertex_buffer_gpu := sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.VERTEX },
        size =  vertices_num_bytes,
    })
    transfer_buffer_queue_append(&vertices, &sdl.GPUBufferRegion{
        buffer = vertex_buffer_gpu,
        offset = 0,
        size = vertices_num_bytes,
    }, nil)

    index_buffer_gpu := sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.INDEX },
        size =  indices_num_bytes,
    })
    transfer_buffer_queue_append(&indices, &sdl.GPUBufferRegion{
        buffer = index_buffer_gpu,
        offset = 0,
        size = indices_num_bytes,
    }, nil)

    transfer_buffer_size:u32 = 0
    for t in transfer_buffer_queue
    {
        transfer_buffer_size += u32(t.size);
    }
    transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo{
        usage = sdl.GPUTransferBufferUsage.UPLOAD,
        size = transfer_buffer_size,
    })
    {
        transfer_map := transmute([^]u8) sdl.MapGPUTransferBuffer(gpu, transfer_buffer, false)
        for t in transfer_buffer_queue
        {
            mem.copy(transfer_map[t.transfer_buffer_offset:], t.source, t.size)
        }
        sdl.UnmapGPUTransferBuffer(gpu, transfer_buffer)
    }

    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
    {
        copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
        transfer_buffer_offset:u32 = 0
        for t in transfer_buffer_queue
        {
            if t.gpu_buffer_region!=nil
            {
                sdl.UploadToGPUBuffer(
                    copy_pass,
                    sdl.GPUTransferBufferLocation{
                        transfer_buffer = transfer_buffer,
                        offset = transfer_buffer_offset,
                    },
                    t.gpu_buffer_region^,
                    false
                )
                transfer_buffer_offset += t.gpu_buffer_region.size
            }
            else if t.gpu_texture_region!=nil
            {
                sdl.UploadToGPUTexture(copy_pass, sdl.GPUTextureTransferInfo{
                        transfer_buffer = transfer_buffer,
                        offset = 0,
                        pixels_per_row = 4,
                        rows_per_layer = 4,
                    },
                    t.gpu_texture_region^,
                    false
                )
                transfer_buffer_offset += u32(t.size)
            }
        }
        sdl.EndGPUCopyPass(copy_pass)
    }
    ok = sdl.SubmitGPUCommandBuffer(copy_cmd_buf)
    assert(ok)
    sdl.ReleaseGPUTransferBuffer(gpu, transfer_buffer)
    delete_dynamic_array(transfer_buffer_queue)// clear_dynamic_array(&transfer_buffer_queue)

    sampler := sdl.CreateGPUSampler(gpu, sdl.GPUSamplerCreateInfo{})

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
        {
            location = 2,
            buffer_slot = 0,
            format = .FLOAT2,
            offset = u32(offset_of(Vertex_Data, uv)),
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
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_width)/f32(window_height), 0.001, 1000.0)
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
        cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)

        swapchain_tex : ^sdl.GPUTexture
        ok = sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf , window , &swapchain_tex , nil , nil)
        assert(ok)

        if swapchain_tex!=nil
        {
            color_target := sdl.GPUColorTargetInfo {
                texture = swapchain_tex ,
                load_op = .CLEAR ,
                clear_color = { 0.2 , 0.2 , 0.2 , 1 } ,
                store_op = .STORE ,
            }

            render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)
            {
                sdl.BindGPUGraphicsPipeline(render_pass, pipeline);

                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = vertex_buffer_gpu, offset = 0}, 1)
                sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = index_buffer_gpu, offset = 0}, sdl.GPUIndexElementSize._16BIT)

                ubo := UBO{
                    mvp = proj_matrix * model_matrix
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

                sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{
                        texture = texture,
                        sampler = sampler,
                    },
                    1
                )
                
                sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)
            }
            sdl.EndGPURenderPass(render_pass)
        }
        else
        {
            // not rendering, window minimized etc.
        }

        ok = sdl.SubmitGPUCommandBuffer(cmd_buf)
        assert(ok)
    }

    delete(arena_buffer)

    when ODIN_DEBUG
    {
        for key, value in tracking_allocator.allocation_map { log.errorf("%v: Leaked %v bytes\n", value.location, value.size) }
        for value in tracking_allocator.bad_free_array { log.errorf("Bad free at: %v\n", value.location) }
    }
}

load_shader :: proc (device: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32, num_samplers: u32) -> ^sdl.GPUShader
{
    return sdl.CreateGPUShader(device, sdl.GPUShaderCreateInfo{
        code_size = len(code),
        code = raw_data(code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = stage,
        num_uniform_buffers = num_uniform_buffers,
        num_samplers = num_samplers,
    })
}

UBO :: struct {
    mvp: matrix[4,4]f32
}
