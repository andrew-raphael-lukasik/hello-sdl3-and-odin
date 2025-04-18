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
import "../game"
import "meshes"
import "textures"
import "gltf2"


init :: proc ()
{
    when ODIN_DEBUG
    {
        sdl.SetLogPriorities(.VERBOSE)
    }
    else
    {
        sdl.SetLogPriorities(.CRITICAL)
    }

    if !sdl.Init({.VIDEO})
    {
        log.fatal(sdl.GetError())
        return
    }

    window = sdl.CreateWindow("Hello SDL3 and Odin", window_size.x, window_size.y, {})
    if window==nil
    {
        log.fatal(sdl.GetError())
        return
    }

    gpu = sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert(gpu!=nil)

    ok := sdl.ClaimWindowForGPUDevice(gpu, window)
    assert(ok)

    renderer = Renderer_State{
        pipeline = nil,
        sampler = nil,

        vertex_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
            usage = { sdl.GPUBufferUsageFlag.VERTEX },
            size = 32_000 * size_of(meshes.Vertex_Data),
        }),
        vertex_buffer_offset = 0,
        
        index_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
            usage = { sdl.GPUBufferUsageFlag.INDEX },
            size =  32_000 * 2,
        }),
        index_buffer_offset = 0,

        vertex_transfer_buffer_offset = 0,
        texture_transfer_buffer_offset = 0,

        draw_calls = make([dynamic]Draw_Call_Data, 0, 32),
    }

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
    schedule_upload_to_gpu_texture(
        source = &textures.default_texture_pixels,
        pixels_per_row = 4,
        rows_per_layer = 4,
        gpu_texture_region = &sdl.GPUTextureRegion{
            texture = default_texture,
            mip_level = 0,
            layer = 0,
            x = 0, y = 0, z = 0,
            w = 4,
            h = 4,
            d = 1,
        }
    )
    
    texture, texture_surface, file_found := textures.load_texture_file(gpu, app.path_to_abs("/data/texture-00.png", context.temp_allocator))
    if file_found
    {
        texture_size := u32(texture_surface.pitch * texture_surface.h)
        schedule_upload_to_gpu_texture_rawptr(
            source = texture_surface.pixels,
            pixels_per_row = u32(texture_surface.w),
            rows_per_layer = u32(texture_surface.h),
            size = texture_size,
            gpu_texture_region = &sdl.GPUTextureRegion{
                texture = texture,
                mip_level = 0,
                layer = 0,
                x = 0, y = 0, z = 0,
                w = u32(texture_surface.w),
                h = u32(texture_surface.h),
                d = 1,
            }
        )
    }
    default_texture = texture

    schedule_upload_to_gpu_buffer(
        source = &meshes.default_quad_vertices,
        gpu_buffer_region = sdl.GPUBufferRegion{
            buffer = renderer.vertex_buffer,
            offset = renderer.vertex_buffer_offset,
            size = meshes.default_quad_vertices_num_bytes,
        }
    )
    renderer.vertex_buffer_offset += meshes.default_quad_vertices_num_bytes

    schedule_upload_to_gpu_buffer(
        source = &meshes.default_quad_indices,
        gpu_buffer_region = sdl.GPUBufferRegion{
            buffer = renderer.index_buffer,
            offset = renderer.index_buffer_offset,
            size = meshes.default_quad_indices_num_bytes,
        }
    )
    renderer.index_buffer_offset += meshes.default_quad_indices_num_bytes

    // create quad entity
    game.create_entity_and_components(
        game.Transform_Component{
            value = matrix[4,4]f32{
                9, 0, 0, 0,
                0, 9, 0, 0,
                0, 0, 9, -10,
                0, 0, 0, 1,
            }
        },
        game.Mesh_Component{
            index_buffer_element_size = sdl.GPUIndexElementSize._16BIT,
            index_buffer_offset = 0,
            vertex_buffer_offset = 0,
            vertex_buffer_num_indices = u32(len(meshes.default_quad_indices)),
        },
        game.Rotation_Component{
            speed = 0.23,
            axis = {0,1,0},
        },
    )

    for mesh_component in create_mesh_components_from_file(app.path_to_abs("/data/default_cube.gltf")) {
        game.create_entity_and_components(
            game.Transform_Component{
                value = matrix[4,4]f32{
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, -10,
                    0, 0, 0, 1,
                }
            },
            mesh_component,
        )
    }

    vertex_transfer_buffer_size := renderer.vertex_transfer_buffer_offset
    vertex_transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo{
        usage = sdl.GPUTransferBufferUsage.UPLOAD,
        size = vertex_transfer_buffer_size,
    })
    {
        transfer_map := transmute([^]u8) sdl.MapGPUTransferBuffer(gpu, vertex_transfer_buffer, false)
        for item in gpu_mesh_buffer_transfer_queue
        {
            assert(item.source!=nil)
            assert(item.size>0)
            mem.copy(transfer_map[item.transfer_buffer_offset:], item.source, int(item.size))
            fmt.printf("MESH mem.copy( transfer_map[{}:], source: %p, size: %d )\n", item.transfer_buffer_offset, item.source, item.size)
        }

        fmt.print("VERTICES: {\n")
        for i:u32=0 ; i<4 ; i+=1 { fmt.printf("\t{}\n", (cast([^]meshes.Vertex_Data) transfer_map)[i]) }
        fmt.print("}\n")

        fmt.print("INDICES: {")
        for i:u32=64 ; i<64+6 ; i+=1 { fmt.printf(", {}", (cast([^]u16) transfer_map)[i]) }
        fmt.print("}\n")

        sdl.UnmapGPUTransferBuffer(gpu, vertex_transfer_buffer)
    }

    texture_transfer_buffer_size := renderer.texture_transfer_buffer_offset
    texture_transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo{
        usage = sdl.GPUTransferBufferUsage.UPLOAD,
        size = texture_transfer_buffer_size,
    })
    {
        transfer_map := transmute([^]u8) sdl.MapGPUTransferBuffer(gpu, texture_transfer_buffer, false)
        for item in gpu_texture_buffer_transfer_queue
        {
            mem.copy(transfer_map[item.transfer_buffer_offset:], item.source, int(item.size))
            fmt.printf("TEXTURE mem.copy( transfer_map[{}:], source: %p, size: %d )\n", item.transfer_buffer_offset, item.source, item.size)
        }
        sdl.UnmapGPUTransferBuffer(gpu, texture_transfer_buffer)
    }
    

    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
    {
        log.debug("sdl.BeginGPUCopyPass()")
        copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
        {
            log.debugf("vertex_transfer_buffer_size: %d", vertex_transfer_buffer_size)
            offset:u32 = 0
            for item in gpu_mesh_buffer_transfer_queue
            {
                log.debugf("GEO t.size: %d, transfer_buffer_offset: %d", item.size, offset)
                sdl.UploadToGPUBuffer(
                    copy_pass,
                    sdl.GPUTransferBufferLocation{
                        transfer_buffer = vertex_transfer_buffer,
                        offset = offset,
                    },
                    item.gpu_buffer_region,
                    false
                )
                offset += item.gpu_buffer_region.size
            }
        }
        {
            log.debugf("texture_transfer_buffer_size: %d", texture_transfer_buffer_size)
            offset:u32 = 0
            for item in gpu_texture_buffer_transfer_queue
            {
                log.debugf("TEX t.size: %d, transfer_buffer_offset: %d", item.size, offset)
                sdl.UploadToGPUTexture(copy_pass, sdl.GPUTextureTransferInfo{
                        transfer_buffer = texture_transfer_buffer,
                        offset = offset,
                        pixels_per_row = item.pixels_per_row,
                        rows_per_layer = item.rows_per_layer,
                    },
                    item.gpu_texture_region^,
                    false
                )
                offset += u32(item.size)
            }
        }
        sdl.EndGPUCopyPass(copy_pass)
        log.debug("sdl.EndGPUCopyPass()")
    }
    ok = sdl.SubmitGPUCommandBuffer(copy_cmd_buf)
    assert(ok)
    sdl.ReleaseGPUTransferBuffer(gpu, vertex_transfer_buffer)
    sdl.ReleaseGPUTransferBuffer(gpu, texture_transfer_buffer)
    clear_dynamic_array(&gpu_mesh_buffer_transfer_queue)
    clear_dynamic_array(&gpu_texture_buffer_transfer_queue)

    renderer.sampler = sdl.CreateGPUSampler(gpu, sdl.GPUSamplerCreateInfo{})

    renderer.pipeline = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
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
            vertex_attributes = raw_data(meshes.vertex_data_attrs),
            num_vertex_attributes = u32(len(meshes.vertex_data_attrs)),
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
    delete_dynamic_array(gpu_mesh_buffer_transfer_queue)
    delete_dynamic_array(gpu_texture_buffer_transfer_queue)
}

tick :: proc ()
{
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_size.x)/f32(window_size.y), 0.001, 1000.0)
    view_matrix := linalg.MATRIX4F32_IDENTITY
    for comp in game.components[game.main_camera] {
        if tc, is := comp.(game.Transform_Component); is {
            view_matrix = tc.value
            break
        }
    }

    // rebuild list of draw calls
    clear(&renderer.draw_calls)
    {
        transform: game.Transform_Component
        mesh: game.Mesh_Component
        for entity in game.entities {
            transform_found, mesh_found: u8
            if components, exist := game.components[entity]; exist {
                for comp in components {
                    if tc, is := comp.(game.Transform_Component); is {
                        transform = tc
                        transform_found = 1
                    }
                    else if mc, is := comp.(game.Mesh_Component); is {
                        mesh = mc
                        mesh_found = 1
                    }
                    if mesh_found==1 && transform_found==1 do break;
                }
            }
            if mesh_found==1 && transform_found==1 {
                append(&renderer.draw_calls, Draw_Call_Data{
                    model_matrix = transform.value,
                    index_buffer_element_size = mesh.index_buffer_element_size,
                    index_buffer_offset = mesh.index_buffer_offset,
                    vertex_buffer_offset = mesh.vertex_buffer_offset,
                    vertex_buffer_num_indices = mesh.vertex_buffer_num_indices,
                })
            }
        }
    }
    
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
            sdl.BindGPUGraphicsPipeline(render_pass, renderer.pipeline)

            for draw in renderer.draw_calls
            {
                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = renderer.vertex_buffer, offset = draw.vertex_buffer_offset}, 1)
                sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = renderer.index_buffer, offset = draw.index_buffer_offset}, draw.index_buffer_element_size)

                ubo := Uniform_Buffer_Object{
                    mvp = proj_matrix * view_matrix * draw.model_matrix,
                    model = draw.model_matrix,
                    view = view_matrix,
                    proj = proj_matrix,
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

                sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{
                        texture = default_texture,
                        sampler = renderer.sampler,
                    },
                    1
                )

                sdl.DrawGPUIndexedPrimitives(
                    render_pass = render_pass,
                    num_indices = draw.vertex_buffer_num_indices,
                    num_instances = 1,
                    first_index = 0,
                    vertex_offset = 0,
                    first_instance = 0,
                )
            }
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

schedule_upload_to_gpu_buffer :: proc (source: ^[]$E, gpu_buffer_region: sdl.GPUBufferRegion)
{
    assert(source!=nil)
    assert(gpu_buffer_region.buffer!=nil)

    dat := UploadToGPUBuffer_Queue_Data{
        transfer_buffer_offset = renderer.vertex_transfer_buffer_offset,
        size = app.num_bytes_of_u32(source),
        source = raw_data(source^),
        gpu_buffer_region = gpu_buffer_region,
    }
    append(&gpu_mesh_buffer_transfer_queue, dat)
    renderer.vertex_transfer_buffer_offset += dat.size

    log.debugf("[schedule_upload_to_gpu_buffer()] scheduled: {}", dat)
}
schedule_upload_to_gpu_texture :: proc (source: ^[]$E, pixels_per_row: u32, rows_per_layer: u32, gpu_texture_region: ^sdl.GPUTextureRegion)
{
    assert(source!=nil)
    assert(gpu_texture_region!=nil)
    assert(pixels_per_row!=0)
    assert(rows_per_layer!=0)

    dat := UploadToGPUTexture_Queue_Data{
        transfer_buffer_offset = renderer.texture_transfer_buffer_offset,
        size = app.num_bytes_of_u32(source),
        source = raw_data(source^),
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_texture_region = gpu_texture_region,
    }
    append(&gpu_texture_buffer_transfer_queue, dat)
    renderer.texture_transfer_buffer_offset += dat.size

    log.debugf("[schedule_upload_to_gpu_texture()] scheduled: {}", dat)
}
schedule_upload_to_gpu_texture_rawptr :: proc (source: rawptr, pixels_per_row: u32, rows_per_layer: u32, size: u32, gpu_texture_region: ^sdl.GPUTextureRegion)
{
    assert(source!=nil)
    assert(gpu_texture_region!=nil)
    assert(pixels_per_row!=0)
    assert(rows_per_layer!=0)

    dat := UploadToGPUTexture_Queue_Data{
        transfer_buffer_offset = renderer.texture_transfer_buffer_offset,
        size = size,
        source = source,
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_texture_region = gpu_texture_region,
    }
    append(&gpu_texture_buffer_transfer_queue, dat)
    renderer.texture_transfer_buffer_offset += dat.size
    log.debugf("[schedule_upload_to_gpu_texture_rawptr()] scheduled: {}", dat)
}

create_mesh_components_from_file :: proc(file_name: string, allocator := context.allocator) -> []game.Mesh_Component {
    a, b := meshes.load_mesh_data_from_file(file_name, allocator)
    return create_mesh_components(a, b, allocator)
}

@(require_results)
create_mesh_components :: proc(vertex_data: [][]meshes.Vertex_Data, index_data: [][]u16, allocator := context.allocator) -> []game.Mesh_Component {
    assert(len(vertex_data)==len(index_data))
    log.debugf("len(vertex_data): {}, len(index_data): {}", len(vertex_data), len(index_data))
    num_items := len(vertex_data)
    mesh_components := make([]game.Mesh_Component, num_items, allocator)
    
    for i:=0 ; i<num_items ; i+=1 {
        indices := index_data[i]
        vertices := vertex_data[i]
        
        mesh_vertex_buffer_offset := renderer.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.vertex_buffer,
                offset = renderer.vertex_buffer_offset,
                size = app.num_bytes_of_u32(&vertices),
            },
        )
        renderer.vertex_buffer_offset += app.num_bytes_of_u32(&vertices)

        vertex_indices_slice := indices[:]
        mesh_index_buffer_offset := renderer.index_buffer_offset
        mesh_vertex_buffer_num_indices := u32(len(indices[:]))
        schedule_upload_to_gpu_buffer(
            source = &vertex_indices_slice,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.index_buffer,
                offset = mesh_index_buffer_offset,
                size = app.num_bytes_of_u32(&vertex_indices_slice),
            },
        )
        renderer.index_buffer_offset += app.num_bytes_of_u32(&vertex_indices_slice)
        
        mesh_components[i] = game.Mesh_Component{
            index_buffer_element_size = sdl.GPUIndexElementSize._16BIT,
            index_buffer_offset = mesh_index_buffer_offset,
            vertex_buffer_offset = mesh_vertex_buffer_offset,
            vertex_buffer_num_indices = mesh_vertex_buffer_num_indices,
        }
    }

    log.debugf("results: {}", mesh_components)
    return mesh_components
}
