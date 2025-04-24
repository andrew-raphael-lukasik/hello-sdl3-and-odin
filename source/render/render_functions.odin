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

    is_mouse_captured := sdl.CaptureMouse(true)

    renderer.vertex_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.VERTEX },
        size = 128_000 * size_of(meshes.Vertex_Data__pos3_uv2_col3),
    })
    renderer.vertex_buffer_offset = 0
    renderer.index_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.INDEX },
        size =  128_000 * size_of(2),
    })
    renderer.index_buffer_offset = 0
    renderer.vertex_transfer_buffer_offset = 0
    renderer.texture_transfer_buffer_offset = 0
    renderer.depth_texture_format = sdl.GPUTextureSupportsFormat(gpu, sdl.GPUTextureFormat.D24_UNORM, sdl.GPUTextureType.D2, {sdl.GPUTextureUsageFlag.DEPTH_STENCIL_TARGET}) ? sdl.GPUTextureFormat.D24_UNORM : sdl.GPUTextureFormat.D16_UNORM
    renderer.depth_texture = sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = renderer.depth_texture_format,
        usage = { sdl.GPUTextureUsageFlag.DEPTH_STENCIL_TARGET },
        width = u32(window_size.x),
        height = u32(window_size.y),
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    renderer.depth_stencil_target_info = sdl.GPUDepthStencilTargetInfo{
        texture = renderer.depth_texture,
        clear_depth = 1,
        load_op = sdl.GPULoadOp.CLEAR,
        store_op = sdl.GPUStoreOp.DONT_CARE,
        // stencil_load_op = sdl.GPULoadOp.CLEAR,
        // stencil_store_op = sdl.GPUStoreOp.DONT_CARE,
        // cycle:            bool,         /**< true cycles the texture if the texture is bound and any load ops are not LOAD */
        // clear_stencil:    Uint8,        /**< The value to clear the stencil component to at the beginning of the render pass. Ignored if GPU_LOADOP_CLEAR is not used. */
    }
    renderer.draw_calls = make_map(map[meshes.GPU_Primitive_Type][dynamic]Draw_Call_Data)
    for t in meshes.GPU_Primitive_Type {
        // renderer.draw_calls[t] = make_dynamic_array([dynamic]Draw_Call_Data)
        // array, err := make([dynamic]Draw_Call_Data)
        // _test := make_dynamic_array_len_cap([dynamic]byte, 0, 16)
        array := make_dynamic_array_len_cap([dynamic]Draw_Call_Data, 0, 16)
        renderer.draw_calls[t] = array
        // assert(err==nil)
        assert(array!=nil)
        assert(renderer.draw_calls[t]!=nil)
    }
    for t in meshes.GPU_Primitive_Type {
        assert(renderer.draw_calls[t]!=nil)
    }

    {
        path := app.path_to_abs("/data/default_shader__IN_col3_uv2_col3__OUT_col3_uv2.spv.vert", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_vert = load_shader(gpu, rawdata, .VERTEX, 1, 0)
    }
    {
        path := app.path_to_abs("/data/default_shader__IN_col3_uv2__OUT_col4.spv.frag", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_frag = load_shader(gpu, rawdata, .FRAGMENT, 0, 1)
    }
    {
        path := app.path_to_abs("/data/default_shader__IN_col3_col3__OUT_col3.spv.vert", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_line_vert = load_shader(gpu, rawdata, .VERTEX, 1, 0)
    }
    {
        path := app.path_to_abs("/data/default_shader__IN_col3__OUT_col3.spv.frag", context.temp_allocator)
        rawdata, ok := os.read_entire_file(path, context.temp_allocator)
        if !ok do log.errorf("file read failed: '{}'", path)
        default_shader_line_frag = load_shader(gpu, rawdata, .FRAGMENT, 0, 1)
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

    // create quad entity
    {
        vertex_buffer_pos := renderer.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &meshes.default_quad_vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.vertex_buffer,
                offset = vertex_buffer_pos,
                size = meshes.default_quad_vertices_num_bytes,
            }
        )
        renderer.vertex_buffer_offset += meshes.default_quad_vertices_num_bytes
    
        index_buffer_pos := renderer.index_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &meshes.default_quad_indices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.index_buffer,
                offset = index_buffer_pos,
                size = meshes.default_quad_indices_num_bytes,
            }
        )
        renderer.index_buffer_offset += meshes.default_quad_indices_num_bytes

        game.create_entity_and_components(
            game.Label_Component{
                value = "rotating quad"
            },
            game.Transform_Component{
                value = matrix[4,4]f32{
                    1, 0, 0, 7,
                    0, 1, 0, 4,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                }
            },
            game.Mesh_Component{
                primitive_type = meshes.GPU_Primitive_Type.TRIANGLELIST,
                index_buffer_element_size = sdl.GPUIndexElementSize._16BIT,
                index_buffer_offset = index_buffer_pos,
                vertex_buffer_offset = vertex_buffer_pos,
                vertex_buffer_num_indices = u32(len(meshes.default_quad_indices)),
            },
            game.Rotation_Component{
                speed = 0.23,
                axis = {0,1,0},
            },
        )
    }

    // create world coords gizmo entity
    {
        vertex_buffer_pos := renderer.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &meshes.axis_vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.vertex_buffer,
                offset = vertex_buffer_pos,
                size = meshes.axis_vertices_num_bytes,
            }
        )
        renderer.vertex_buffer_offset += meshes.axis_vertices_num_bytes
    
        index_buffer_pos := renderer.index_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &meshes.axis_indices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.index_buffer,
                offset = index_buffer_pos,
                size = meshes.axis_indices_num_bytes,
            }
        )
        renderer.index_buffer_offset += meshes.axis_indices_num_bytes

        game.create_entity_and_components(
            game.Label_Component{
                value = "world coords gizmo"
            },
            game.Transform_Component{
                value = matrix[4,4]f32{
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                }
            },
            game.Mesh_Component{
                primitive_type = meshes.GPU_Primitive_Type.LINELIST,
                index_buffer_element_size = sdl.GPUIndexElementSize._16BIT,
                index_buffer_offset = index_buffer_pos,
                vertex_buffer_offset = vertex_buffer_pos,
                vertex_buffer_num_indices = u32(len(meshes.axis_indices)),
            },
        )
    }

    mesh_components, mesh_objects := create_mesh_components_from_file(app.path_to_abs("/data/default_cube.gltf"))
    for mesh_object in mesh_objects {
        cx: [3]f32 = linalg.quaternion128_mul_vector3(mesh_object.rotation, [3]f32{mesh_object.scale.x, 0, 0})
        cy: [3]f32 = linalg.quaternion128_mul_vector3(mesh_object.rotation, [3]f32{0, mesh_object.scale.y, 0})
        cz: [3]f32 = linalg.quaternion128_mul_vector3(mesh_object.rotation, [3]f32{0, 0, mesh_object.scale.z})
        ct: [3]f32 = mesh_object.translation
        game.create_entity_and_components(
            game.Label_Component{
                value = "mesh"
            },
            game.Transform_Component{
                value = matrix[4,4]f32{
                    cx[0], cy[0], cz[0], ct[0],
                    cx[1], cy[1], cz[1], ct[1],
                    cx[2], cy[2], cz[2], ct[2],
                    0, 0, 0, 1,
                }
            },
            mesh_components[mesh_object.mesh_index],
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

        fmt.print("default quad mesh vertices: {\n")
        for i:u32=0 ; i<4 ; i+=1 { fmt.printf("\t{}\n", (cast([^]meshes.Vertex_Data__pos3_uv2_col3) transfer_map)[i]) }
        fmt.print("}\n")

        fmt.print("default quad mesh indices: {")
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

    renderer.pipeline_triangle_list = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = default_shader_vert,
        fragment_shader = default_shader_frag,
        primitive_type = sdl.GPUPrimitiveType.TRIANGLELIST,
        vertex_input_state = {
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription{
                slot = 0,
                pitch = size_of(meshes.Vertex_Data__pos3_uv2_col3),
                input_rate = .VERTEX,
            },
            num_vertex_buffers = 1,
            vertex_attributes = raw_data(meshes.vertex_attrs__pos3_uv2_col3),
            num_vertex_attributes = u32(len(meshes.vertex_attrs__pos3_uv2_col3)),
        },
        depth_stencil_state = sdl.GPUDepthStencilState{
            compare_op = sdl.GPUCompareOp.LESS,
            back_stencil_state = sdl.GPUStencilOpState{
                // fail_op:       GPUStencilOp, /**< The action performed on samples that fail the stencil test. */
                // pass_op:       GPUStencilOp, /**< The action performed on samples that pass the depth and stencil tests. */
                // depth_fail_op: GPUStencilOp, /**< The action performed on samples that pass the stencil test and fail the depth test. */
                // compare_op:    GPUCompareOp, /**< The comparison operator used in the stencil test. */
            },  /**< The stencil op state for back-facing triangles. */
            front_stencil_state = sdl.GPUStencilOpState{
                // fail_op:       GPUStencilOp, /**< The action performed on samples that fail the stencil test. */
                // pass_op:       GPUStencilOp, /**< The action performed on samples that pass the depth and stencil tests. */
                // depth_fail_op: GPUStencilOp, /**< The action performed on samples that pass the stencil test and fail the depth test. */
                // compare_op:    GPUCompareOp, /**< The comparison operator used in the stencil test. */
            },  /**< The stencil op state for front-facing triangles. */
            // compare_mask:        Uint8,              /**< Selects the bits of the stencil values participating in the stencil test. */
            // write_mask:          Uint8,              /**< Selects the bits of the stencil values updated by the stencil test. */
            enable_depth_test = true,
            enable_depth_write = true,
            // enable_stencil_test = false,/**< true enables the stencil test. */
        },
        target_info = sdl.GPUGraphicsPipelineTargetInfo{
            color_target_descriptions = &(sdl.GPUColorTargetDescription{
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
                // blend_state = sdl.GPUColorTargetBlendState{
                //     enable_blend = false,
                //     src_color_blendfactor = sdl.GPUBlendFactor.ONE,
                //     dst_color_blendfactor = sdl.GPUBlendFactor.ZERO,
                //     color_blend_op = sdl.GPUBlendOp.ADD,
                //     src_alpha_blendfactor = sdl.GPUBlendFactor.ONE,
                //     dst_alpha_blendfactor = sdl.GPUBlendFactor.ZERO,
                //     alpha_blend_op = sdl.GPUBlendOp.ADD,
                //     enable_color_write_mask = false,
                //     color_write_mask = {(sdl.GPUColorComponentFlag.R | sdl.GPUColorComponentFlag.G | sdl.GPUColorComponentFlag.B | sdl.GPUColorComponentFlag.A)},
                // },
            }),
            num_color_targets = 1,
            depth_stencil_format = renderer.depth_texture_format,
            has_depth_stencil_target = true,
        }
    } )
    renderer.pipeline_line_list = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = default_shader_line_vert,
        fragment_shader = default_shader_line_frag,
        primitive_type = sdl.GPUPrimitiveType.LINELIST,
        vertex_input_state = sdl.GPUVertexInputState{
            vertex_buffer_descriptions = &sdl.GPUVertexBufferDescription{
                slot = 0,
                pitch = size_of(meshes.Vertex_Data__pos3_col3),
                input_rate = sdl.GPUVertexInputRate.VERTEX,
            },
            num_vertex_buffers = 1,
            vertex_attributes = raw_data(meshes.vertex_attrs__pos3_col3),
            num_vertex_attributes = u32(len(meshes.vertex_attrs__pos3_col3)),
        },
        depth_stencil_state = sdl.GPUDepthStencilState{
            compare_op = sdl.GPUCompareOp.ALWAYS,
            back_stencil_state = sdl.GPUStencilOpState{
                // fail_op:       GPUStencilOp, /**< The action performed on samples that fail the stencil test. */
                // pass_op:       GPUStencilOp, /**< The action performed on samples that pass the depth and stencil tests. */
                // depth_fail_op: GPUStencilOp, /**< The action performed on samples that pass the stencil test and fail the depth test. */
                // compare_op:    GPUCompareOp, /**< The comparison operator used in the stencil test. */
            },  /**< The stencil op state for back-facing triangles. */
            front_stencil_state = sdl.GPUStencilOpState{
                // fail_op:       GPUStencilOp, /**< The action performed on samples that fail the stencil test. */
                // pass_op:       GPUStencilOp, /**< The action performed on samples that pass the depth and stencil tests. */
                // depth_fail_op: GPUStencilOp, /**< The action performed on samples that pass the stencil test and fail the depth test. */
                // compare_op:    GPUCompareOp, /**< The comparison operator used in the stencil test. */
            },  /**< The stencil op state for front-facing triangles. */
            // compare_mask:        Uint8,              /**< Selects the bits of the stencil values participating in the stencil test. */
            // write_mask:          Uint8,              /**< Selects the bits of the stencil values updated by the stencil test. */
            enable_depth_test = true,
            enable_depth_write = true,
            // enable_stencil_test = false,/**< true enables the stencil test. */
        },
        target_info = sdl.GPUGraphicsPipelineTargetInfo{
            color_target_descriptions = &(sdl.GPUColorTargetDescription{
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
                // blend_state = sdl.GPUColorTargetBlendState{
                //     enable_blend = false,
                //     src_color_blendfactor = sdl.GPUBlendFactor.ONE,
                //     dst_color_blendfactor = sdl.GPUBlendFactor.ZERO,
                //     color_blend_op = sdl.GPUBlendOp.ADD,
                //     src_alpha_blendfactor = sdl.GPUBlendFactor.ONE,
                //     dst_alpha_blendfactor = sdl.GPUBlendFactor.ZERO,
                //     alpha_blend_op = sdl.GPUBlendOp.ADD,
                //     enable_color_write_mask = false,
                //     color_write_mask = {(sdl.GPUColorComponentFlag.R | sdl.GPUColorComponentFlag.G | sdl.GPUColorComponentFlag.B | sdl.GPUColorComponentFlag.A)},
                // },
            }),
            num_color_targets = 1,
            depth_stencil_format = renderer.depth_texture_format,
            has_depth_stencil_target = true,
        }
    } )

    sdl.ReleaseGPUShader(gpu, default_shader_vert)
    sdl.ReleaseGPUShader(gpu, default_shader_frag)
    sdl.ReleaseGPUShader(gpu, default_shader_line_vert)
    sdl.ReleaseGPUShader(gpu, default_shader_line_frag)
}

close :: proc ()
{
    sdl.DestroyWindow(window)
    sdl.ReleaseGPUTexture(gpu, renderer.depth_texture)
    sdl.Quit()
    delete(renderer.draw_calls)
    delete_dynamic_array(gpu_mesh_buffer_transfer_queue)
    delete_dynamic_array(gpu_texture_buffer_transfer_queue)
}

tick :: proc ()
{
    sdl.GetWindowSize(window, &window_size.x, &window_size.y)
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_size.x)/f32(window_size.y), 0.001, 1000.0)
    view_matrix := linalg.MATRIX4F32_IDENTITY
    for comp in game.components[game.main_camera] {
        if tc, is := comp.(game.Transform_Component); is {
            view_matrix = linalg.inverse(tc.value)
            break
        }
    }

    // rebuild list of draw calls
    for key in renderer.draw_calls {
        clear_dynamic_array(&renderer.draw_calls[key])
    }
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
                draw_calls_array := renderer.draw_calls[mesh.primitive_type]
                append(&draw_calls_array, Draw_Call_Data{
                    model_matrix = transform.value,
                    index_buffer_element_size = mesh.index_buffer_element_size,
                    index_buffer_offset = mesh.index_buffer_offset,
                    vertex_buffer_offset = mesh.vertex_buffer_offset,
                    vertex_buffer_num_indices = mesh.vertex_buffer_num_indices,
                })
                renderer.draw_calls[mesh.primitive_type] = draw_calls_array
                assert(len(renderer.draw_calls[mesh.primitive_type])!=0)
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

        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, &renderer.depth_stencil_target_info)
        {
            sdl.BindGPUGraphicsPipeline(render_pass, renderer.pipeline_triangle_list)
            assert(renderer.draw_calls[meshes.GPU_Primitive_Type.TRIANGLELIST]!=nil)
            for draw in renderer.draw_calls[meshes.GPU_Primitive_Type.TRIANGLELIST]
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

            sdl.BindGPUGraphicsPipeline(render_pass, renderer.pipeline_line_list)
            assert(renderer.draw_calls[meshes.GPU_Primitive_Type.LINELIST]!=nil)
            for draw in renderer.draw_calls[meshes.GPU_Primitive_Type.LINELIST]
            {
                // log.warnf("line draw: {}", draw)
                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = renderer.vertex_buffer, offset = draw.vertex_buffer_offset}, 1)
                sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = renderer.index_buffer, offset = draw.index_buffer_offset}, draw.index_buffer_element_size)
                ubo := Uniform_Buffer_Object{
                    mvp = proj_matrix * view_matrix * draw.model_matrix,
                    model = draw.model_matrix,
                    view = view_matrix,
                    proj = proj_matrix,
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
                sdl.DrawGPUPrimitives(
                    render_pass = render_pass,
                    num_vertices = draw.vertex_buffer_num_indices,
                    num_instances = 1,
                    first_vertex = 0,
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

    assert((dat.size+dat.transfer_buffer_offset)<=renderer.vertex_transfer_buffer_offset, "this GPU buffer is too small")
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

    assert((dat.size+dat.transfer_buffer_offset)<=renderer.texture_transfer_buffer_offset, "this GPU buffer is too small")
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

    assert((dat.size+dat.transfer_buffer_offset)<=renderer.texture_transfer_buffer_offset, "this GPU buffer is too small")
    log.debugf("[schedule_upload_to_gpu_texture_rawptr()] scheduled: {}", dat)
}

create_mesh_components_from_file :: proc(file_name: string, allocator := context.allocator) -> ([]game.Mesh_Component, []meshes.GLTF_Mesh_Object_Info) {
    vertex_data_array, index_data_array, index_element_size_array, mesh_object_array := meshes.load_mesh_data_from_file(file_name, allocator)
    return create_mesh_components(vertex_data_array, index_data_array, index_element_size_array, allocator), mesh_object_array
}

@(require_results)
create_mesh_components :: proc(vertex_data: [][]meshes.Vertex_Data__pos3_uv2_col3, index_data: [][]byte, index_size: []sdl.GPUIndexElementSize, allocator := context.allocator) -> []game.Mesh_Component {
    assert(len(vertex_data)==len(index_data))
    log.debugf("len(vertex_data): {}, len(index_data): {}", len(vertex_data), len(index_data))
    num_items := len(vertex_data)
    mesh_components := make([]game.Mesh_Component, num_items, allocator)
    
    for i:=0 ; i<num_items ; i+=1 {
        indices := index_data[i]
        index_element_size := index_size[i]
        index_element_stride: u32
        switch  index_size[i]
        {
            case sdl.GPUIndexElementSize._16BIT: index_element_stride = 2
            case sdl.GPUIndexElementSize._32BIT: index_element_stride = 4
            case: assert(false, fmt.aprintf("{} not implemented", index_size[i]))
        }
        vertices := vertex_data[i]
        
        mesh_vertex_buffer_pos := renderer.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = &vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = renderer.vertex_buffer,
                offset = mesh_vertex_buffer_pos,
                size = app.num_bytes_of_u32(&vertices),
            },
        )
        renderer.vertex_buffer_offset += app.num_bytes_of_u32(&vertices)

        indices_slice := indices[:]
        mesh_index_buffer_pos := renderer.index_buffer_offset
        mesh_vertex_buffer_num_indices := app.num_bytes_of_u32(&indices_slice) / index_element_stride
        gpu_buffer_region := sdl.GPUBufferRegion{
            buffer = renderer.index_buffer,
            offset = mesh_index_buffer_pos,
            size = app.num_bytes_of_u32(&indices_slice),
        }
        schedule_upload_to_gpu_buffer(
            source = &indices_slice,
            gpu_buffer_region = gpu_buffer_region,
        )
        renderer.index_buffer_offset += gpu_buffer_region.size
        
        mesh_components[i] = game.Mesh_Component{
            primitive_type = meshes.GPU_Primitive_Type.TRIANGLELIST,
            index_buffer_element_size = index_size[i],
            index_buffer_offset = mesh_index_buffer_pos,
            vertex_buffer_offset = mesh_vertex_buffer_pos,
            vertex_buffer_num_indices = mesh_vertex_buffer_num_indices,
        }
    }

    log.debugf("results: {}", mesh_components)
    return mesh_components
}
