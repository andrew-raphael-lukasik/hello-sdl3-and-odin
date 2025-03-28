package render
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "vendor:cgltf"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:math/linalg"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:log"
import "../app"
import "meshes"
import "textures"


init :: proc ()
{
    when ODIN_DEBUG
    {
        sdl.SetLogPriorities(.INFO)
    }
    else
    {
        sdl.SetLogPriorities(.CRITICAL)
    }

    if !sdl.Init({.VIDEO})
    {
        fmt.eprintln(sdl.GetError())
        return
    }

    window = sdl.CreateWindow("Hello SDL3 and Odin", window_size.x, window_size.y, {})
    if window==nil
    {
        fmt.eprintln(sdl.GetError())
        return
    }

    gpu = sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert(gpu!=nil)

    ok := sdl.ClaimWindowForGPUDevice(gpu, window)
    assert(ok)

    {
        path := app.path_to_abs("/data/default_shader.spv.vert", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_vert = load_shader(gpu, rawdata, .VERTEX, 1, 0)
    }
    {
        path := app.path_to_abs("/data/default_shader.spv.frag", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_frag = load_shader(gpu, rawdata, .FRAGMENT, 0, 1)
    }

    default_texture = textures.create_default_texture(gpu)
    transfer_buffer_queue_append(source = &textures.default_texture_pixels, pixels_per_row = 4, rows_per_layer = 4, gpu_buffer_region = nil, gpu_texture_region = &sdl.GPUTextureRegion{
        texture = default_texture,
        mip_level = 0,
        layer = 0,
        x = 0,
        y = 0,
        z = 0,
        w = 4,
        h = 4,
        d = 1,
    })

    vertex_buffer_gpu = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.VERTEX },
        size =  meshes.default_quad_vertices_num_bytes,
    })
    transfer_buffer_queue_append(source = &meshes.default_quad_vertices, pixels_per_row = 4, rows_per_layer = 4, gpu_buffer_region = &sdl.GPUBufferRegion{
        buffer = vertex_buffer_gpu,
        offset = 0,
        size = meshes.default_quad_vertices_num_bytes,
    }, gpu_texture_region = nil)

    index_buffer_gpu = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.INDEX },
        size =  meshes.default_quad_indices_num_bytes,
    })
    transfer_buffer_queue_append(source = &meshes.default_quad_indices, pixels_per_row = 4, rows_per_layer = 4, gpu_buffer_region = &sdl.GPUBufferRegion{
        buffer = index_buffer_gpu,
        offset = 0,
        size = meshes.default_quad_indices_num_bytes,
    }, gpu_texture_region = nil)

    transfer_buffer_size:u32 = 0
    for t in transfer_buffer_queue
    {
        transfer_buffer_size += u32(t.size)
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
                        pixels_per_row = t.pixels_per_row,
                        rows_per_layer = t.rows_per_layer,
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
    clear_dynamic_array(&transfer_buffer_queue)

    sampler = sdl.CreateGPUSampler(gpu, sdl.GPUSamplerCreateInfo{})

    pipeline = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = default_shader_vert,
        fragment_shader = default_shader_frag,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription{
                slot = 0,
                pitch = size_of(meshes.Vertex_Data),
                input_rate = .VERTEX,
            },
            num_vertex_buffers = 1,
            vertex_attributes = raw_data(meshes.default_quad_vert_attrs),
            num_vertex_attributes = u32(len(meshes.default_quad_vert_attrs)),
        },
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription{
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window)
            })
        }
    } )

    sdl.ReleaseGPUShader(gpu, default_shader_vert)
    sdl.ReleaseGPUShader(gpu, default_shader_frag)

    sdl.GetWindowSize(window, &window_size.x, &window_size.y)
}

close :: proc ()
{
    sdl.DestroyWindow(window)
    sdl.Quit()
    delete_dynamic_array(transfer_buffer_queue)
}

tick :: proc ()
{
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_size.x)/f32(window_size.y), 0.001, 1000.0)
    view_matrix := linalg.MATRIX4F32_IDENTITY
    model_matrix := linalg.matrix4_rotate_f32(f32(linalg.TAU)*f32(app.time_tick), linalg.Vector3f32{0,1,0})
    model_matrix[3][0] = 0
    model_matrix[3][1] = 0
    model_matrix[3][2] = -10

    cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)

    swapchain_tex : ^sdl.GPUTexture
    ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf , window , &swapchain_tex , nil , nil)
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
            sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

            sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = vertex_buffer_gpu, offset = 0}, 1)
            sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = index_buffer_gpu, offset = 0}, sdl.GPUIndexElementSize._16BIT)

            ubo := Uniform_Buffer_Object{
                mvp = proj_matrix * model_matrix,
                model = model_matrix,
                view = view_matrix,
                proj = proj_matrix,
            }
            sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

            sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{
                    texture = default_texture,
                    sampler = sampler,
                },
                1
            )
            
            sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(meshes.default_quad_indices)), 1, 0, 0, 0)
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

transfer_buffer_queue_append :: proc (source: ^[]$E, pixels_per_row: u32, rows_per_layer: u32, gpu_buffer_region: ^sdl.GPUBufferRegion, gpu_texture_region: ^sdl.GPUTextureRegion,)
{
    offset := 0  
    {
        l := len(transfer_buffer_queue)
        if l!=0
        {
            offset = transfer_buffer_queue[l-1].transfer_buffer_offset + transfer_buffer_queue[l-1].size
        }
    }
    append(&transfer_buffer_queue, Transfer_Buffer_Queue_Item{
        transfer_buffer_offset = offset,
        size = app.num_bytes_of(source),
        source = raw_data(source^),
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_buffer_region = gpu_buffer_region,
        gpu_texture_region = gpu_texture_region,
    })
}
transfer_buffer_queue_append_rawptr :: proc (source: rawptr, pixels_per_row: u32, rows_per_layer: u32, size: int, gpu_buffer_region: ^sdl.GPUBufferRegion, gpu_texture_region: ^sdl.GPUTextureRegion,)
{
    offset := 0  
    {
        l := len(transfer_buffer_queue)
        if l!=0
        {
            offset = transfer_buffer_queue[l-1].transfer_buffer_offset + transfer_buffer_queue[l-1].size
        }
    }
    append(&transfer_buffer_queue, Transfer_Buffer_Queue_Item{
        transfer_buffer_offset = offset,
        size = size,
        source = source,
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_buffer_region = gpu_buffer_region,
        gpu_texture_region = gpu_texture_region,
    })
}
