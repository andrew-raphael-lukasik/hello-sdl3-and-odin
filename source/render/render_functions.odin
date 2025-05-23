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
import "core:math/rand"
import "base:runtime"
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

    state.vertex_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.VERTEX },
        size = 128_000 * size_of(meshes.Vertex_Data__pos3_uv2_col3),
    })
    state.vertex_buffer_offset = 0
    state.index_buffer = sdl.CreateGPUBuffer(gpu, sdl.GPUBufferCreateInfo{
        usage = { sdl.GPUBufferUsageFlag.INDEX },
        size =  128_000 * size_of(2),
    })
    state.index_buffer_offset = 0
    state.vertex_transfer_buffer_offset = 0
    state.texture_transfer_buffer_offset = 0
    state.depth_texture_format = sdl.GPUTextureSupportsFormat(gpu, sdl.GPUTextureFormat.D24_UNORM, sdl.GPUTextureType.D2, {sdl.GPUTextureUsageFlag.DEPTH_STENCIL_TARGET}) ? sdl.GPUTextureFormat.D24_UNORM : sdl.GPUTextureFormat.D16_UNORM
    state.depth_texture = sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = state.depth_texture_format,
        usage = { sdl.GPUTextureUsageFlag.DEPTH_STENCIL_TARGET },
        width = u32(window_size.x),
        height = u32(window_size.y),
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    state.depth_stencil_target_info = sdl.GPUDepthStencilTargetInfo{
        texture = state.depth_texture,
        clear_depth = 1,
        load_op = sdl.GPULoadOp.CLEAR,
        store_op = sdl.GPUStoreOp.DONT_CARE,
        // stencil_load_op = sdl.GPULoadOp.CLEAR,
        // stencil_store_op = sdl.GPUStoreOp.DONT_CARE,
        // cycle:            bool,         /**< true cycles the texture if the texture is bound and any load ops are not LOAD */
        // clear_stencil:    Uint8,        /**< The value to clear the stencil component to at the beginning of the render pass. Ignored if GPU_LOADOP_CLEAR is not used. */
    }
    state.draw_calls = make_map(map[meshes.GPU_Primitive_Type][dynamic]Draw_Call_Data)
    for t in meshes.GPU_Primitive_Type {
        // state.draw_calls[t] = make_dynamic_array([dynamic]Draw_Call_Data)
        // array, err := make([dynamic]Draw_Call_Data)
        // _test := make_dynamic_array_len_cap([dynamic]byte, 0, 16)
        array := make_dynamic_array_len_cap([dynamic]Draw_Call_Data, 0, 16)
        state.draw_calls[t] = array
        // assert(err==nil)
        assert(array!=nil)
        assert(state.draw_calls[t]!=nil)
    }
    for t in meshes.GPU_Primitive_Type {
        assert(state.draw_calls[t]!=nil)
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
        source = textures.default_texture_pixels,
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
        vertex_buffer_pos := state.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = meshes.default_quad_vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = state.vertex_buffer,
                offset = vertex_buffer_pos,
                size = meshes.default_quad_vertices_num_bytes,
            }
        )
        state.vertex_buffer_offset += meshes.default_quad_vertices_num_bytes
    
        index_buffer_pos := state.index_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = meshes.default_quad_indices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = state.index_buffer,
                offset = index_buffer_pos,
                size = meshes.default_quad_indices_num_bytes,
            }
        )
        state.index_buffer_offset += meshes.default_quad_indices_num_bytes

        entity := game.create_entity_and_components(
            game.Label_Component{
                value = "rotating quad"
            },
            game.Mesh_Component{
                primitive_type = meshes.GPU_Primitive_Type.TRIANGLELIST,
                
                index_buffer_offset = index_buffer_pos,
                index_buffer_stride = size_of(meshes.default_quad_indices[0]),
                index_buffer_length = u32(len(meshes.default_quad_indices)),
                
                vertex_buffer_offset = vertex_buffer_pos,
                vertex_buffer_type = type_of(meshes.default_quad_vertices[0]),
                vertex_buffer_length = u32(len(meshes.default_quad_vertices)),
            },
            game.Rotation_Component{
                speed = 0.23,
                axis = {0,1,0},
                offset = rand.float32() * 10
            },
        )
        game.transforms[entity] = game.Transform{
            matrix3x3 = linalg.MATRIX3F32_IDENTITY,
            translation = {7, 4, 0},
        }
    }

    // create world coords gizmo entity
    {
        vertex_buffer_pos := state.vertex_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = meshes.axis_vertices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = state.vertex_buffer,
                offset = vertex_buffer_pos,
                size = meshes.axis_vertices_num_bytes,
            }
        )
        state.vertex_buffer_offset += meshes.axis_vertices_num_bytes
    
        index_buffer_pos := state.index_buffer_offset
        schedule_upload_to_gpu_buffer(
            source = meshes.axis_indices,
            gpu_buffer_region = sdl.GPUBufferRegion{
                buffer = state.index_buffer,
                offset = index_buffer_pos,
                size = meshes.axis_indices_num_bytes,
            }
        )
        state.index_buffer_offset += meshes.axis_indices_num_bytes

        entity := game.create_entity_and_components(
            game.Label_Component{
                value = "world coords gizmo"
            },
            game.Mesh_Component{
                primitive_type = meshes.GPU_Primitive_Type.LINELIST,
                
                index_buffer_offset = index_buffer_pos,
                index_buffer_stride = 2,
                index_buffer_length = u32(len(meshes.axis_indices)),
                
                vertex_buffer_offset = vertex_buffer_pos,
                vertex_buffer_type = type_of(meshes.axis_vertices[0]),
                vertex_buffer_length = u32(len(meshes.axis_vertices)),
            },
        )
        game.transforms[entity] = game.Transform{
            matrix3x3 = linalg.MATRIX3F32_IDENTITY,
            translation = {0, 0, 0},
        }
    }

    {
        all_mesh_components, gltf_mesh_nodes := create_mesh_components_from_file(app.path_to_abs("/data/DamagedHelmet.gltf", context.temp_allocator))
        for gltf_mesh_node in gltf_mesh_nodes {
            entity := game.create_entity_and_components(
                game.Label_Component{
                    value = fmt.aprintf("DamagedHelmet.gltf mesh {}", gltf_mesh_node.mesh_index)
                },
            )

            xxx := linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{gltf_mesh_node.scale.x, 0, 0})
            yyy := linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{0, gltf_mesh_node.scale.y, 0})
            zzz := linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{0, 0, gltf_mesh_node.scale.z})
            pos := gltf_mesh_node.translation
            game.transforms[entity] = game.Transform{
                matrix3x3 = matrix[3,3]f32{
                    xxx[0], yyy[0], zzz[0],
                    xxx[1], yyy[1], zzz[1],
                    xxx[2], yyy[2], zzz[2],
                },
                translation = pos,
            }
            
            node_mesh_components := all_mesh_components[gltf_mesh_node.mesh_index]
            for mesh_component in node_mesh_components {
                append(&game.components[entity], mesh_component)
            }
        }
    }
    {
        all_mesh_components, gltf_mesh_nodes := create_mesh_components_from_file(app.path_to_abs("/data/de_chateau.gltf", context.temp_allocator))
        for gltf_mesh_node in gltf_mesh_nodes {
            entity := game.create_entity_and_components(
                game.Label_Component{
                    value = fmt.aprintf("other gltf mesh {}", gltf_mesh_node.mesh_index)
                },
            )

            cx: [3]f32 = linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{gltf_mesh_node.scale.x, 0, 0})
            cy: [3]f32 = linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{0, gltf_mesh_node.scale.y, 0})
            cz: [3]f32 = linalg.quaternion128_mul_vector3(gltf_mesh_node.rotation, [3]f32{0, 0, gltf_mesh_node.scale.z})
            ct: [3]f32 = gltf_mesh_node.translation
            game.transforms[entity] = game.Transform{
                matrix3x3 = matrix[3,3]f32{
                    cx[0], cy[0], cz[0],
                    cx[1], cy[1], cz[1],
                    cx[2], cy[2], cz[2],
                },
                translation = ct + {5, 0, 0}
            }

            node_mesh_components := all_mesh_components[gltf_mesh_node.mesh_index]
            for mesh_component in node_mesh_components {
                append(&game.components[entity], mesh_component)
            }
        }
    }

    vertex_transfer_buffer_size := state.vertex_transfer_buffer_offset
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

        app.log_print_slice((transmute([^]meshes.Vertex_Data__pos3_uv2_col3) transfer_map) [:4], "default quad mesh vertices", true)
        // app.log_print_slice((transmute([^]meshes.Vertex_Data__pos3_uv2_col3) transfer_map) [:4], "default quad mesh vertices B", true)
        app.log_print_slice((transmute([^]u16) transfer_map) [64:64+6], "default quad mesh indices", false)
        // app.log_print_slice(mem.slice_data_cast([]u16, transfer_map), "default quad mesh indices B", false)

        for entity in game.entities {
            if components, exist := game.components[entity]; exist {
                for comp in components {
                    if mc, is := comp.(game.Mesh_Component); is {
                        log.debugf("entity {} has a mesh component, data sent to GPU:", entity)
                        switch mc.vertex_buffer_type
                        {
                            case meshes.Vertex_Data__pos3_uv2_col3:
                            {
                                start := mc.vertex_buffer_offset
                                end := mc.vertex_buffer_offset + mc.vertex_buffer_length * size_of(meshes.Vertex_Data__pos3_uv2_col3)
                                bytes := transfer_map [start:end]
                                verts :=  mem.slice_data_cast([]meshes.Vertex_Data__pos3_uv2_col3, bytes)
                                // app.log_print_slice(verts, "vertices", true)
                            }
                            case meshes.Vertex_Data__pos3_col3:
                            {
                                start := mc.vertex_buffer_offset
                                end := mc.vertex_buffer_offset + mc.vertex_buffer_length * size_of(meshes.Vertex_Data__pos3_col3)
                                bytes := transfer_map [start:end]
                                verts :=  mem.slice_data_cast([]meshes.Vertex_Data__pos3_col3, bytes)
                                // app.log_print_slice(verts, "vertices", true)
                            }
                            case: log.errorf("vertex_buffer_type not implemented: {}", mc.vertex_buffer_type)
                        }
                        start := mc.index_buffer_offset
                        end := mc.index_buffer_offset + mc.index_buffer_length * u32(mc.index_buffer_stride)
                        bytes := transfer_map [start:end]
                        // app.log_print_slice(bytes, "entity mesh indices as bytes", false)
                        assert(end-start==u32(len(bytes)))
                        assert(mc.index_buffer_length==u32(len(bytes))/u32(mc.index_buffer_stride))
                        switch mc.index_buffer_stride
                        {
                            case size_of(u16):
                            {
                                indices := mem.slice_data_cast([]u16, bytes)
                                // indices = meshes.bytes_to_u16_slice(bytes, false)
                                // indices = (transmute([^]u16) transfer_map) [start:end]
                                app.log_print_slice(indices, "entity mesh indices", false)
                            }
                            case size_of(u32):
                            {
                                indices := mem.slice_data_cast([]u32, bytes)
                                app.log_print_slice(indices, "entity mesh indices", false)
                            }
                            case: log.errorf("index_buffer_stride not implemented: {}", mc.index_buffer_stride)
                        }
                    }
                }
            }
        }

        sdl.UnmapGPUTransferBuffer(gpu, vertex_transfer_buffer)
    }

    texture_transfer_buffer_size := state.texture_transfer_buffer_offset
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

    state.sampler = sdl.CreateGPUSampler(gpu, sdl.GPUSamplerCreateInfo{})

    state.pipeline_triangle_list = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
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
            depth_stencil_format = state.depth_texture_format,
            has_depth_stencil_target = true,
        }
    } )
    state.pipeline_line_list = sdl.CreateGPUGraphicsPipeline(gpu, sdl.GPUGraphicsPipelineCreateInfo{
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
            depth_stencil_format = state.depth_texture_format,
            has_depth_stencil_target = true,
        }
    } )

    sdl.ReleaseGPUShader(gpu, default_shader_vert)
    sdl.ReleaseGPUShader(gpu, default_shader_frag)
    sdl.ReleaseGPUShader(gpu, default_shader_line_vert)
    sdl.ReleaseGPUShader(gpu, default_shader_line_frag)

    game.log_print_entity_components()
}

close :: proc ()
{
    sdl.DestroyWindow(window)
    sdl.ReleaseGPUTexture(gpu, state.depth_texture)
    sdl.Quit()
    delete(state.draw_calls)
    delete_dynamic_array(gpu_mesh_buffer_transfer_queue)
    delete_dynamic_array(gpu_texture_buffer_transfer_queue)
}

tick :: proc ()
{
    sdl.GetWindowSize(window, &window_size.x, &window_size.y)
    proj_matrix := linalg.matrix4_perspective_f32(70, f32(window_size.x)/f32(window_size.y), 0.001, 1000.0)
    view_matrix := linalg.MATRIX4F32_IDENTITY
    main_camera_transform := game.transforms[game.main_camera]
    {
        m4x4 := linalg.matrix4_from_matrix3_f32(main_camera_transform.matrix3x3)
        m4x4[3].xyz = main_camera_transform.translation
        view_matrix = linalg.inverse(m4x4)
    }

    // rebuild list of draw calls
    for key in state.draw_calls {
        clear_dynamic_array(&state.draw_calls[key])
    }
    num_draw_calls := 0
    for entity in game.entities {
        if components, exist := game.components[entity]; exist {
            for comp in components {
                if mc, is := comp.(game.Mesh_Component); is {
                    draw_calls_array := state.draw_calls[mc.primitive_type]
                    {
                        transform := game.transforms[entity]
                        m4x4 := linalg.matrix4_from_matrix3_f32(transform.matrix3x3)
                        m4x4[3].xyz = transform.translation
                        append(&draw_calls_array, Draw_Call_Data{
                            model_matrix = m4x4,
                            index_buffer_offset = mc.index_buffer_offset,
                            index_buffer_stride = mc.index_buffer_stride,
                            index_buffer_length = mc.index_buffer_length,
                            vertex_buffer_offset = mc.vertex_buffer_offset,
                        })
                    }
                    state.draw_calls[mc.primitive_type] = draw_calls_array
                    assert(len(state.draw_calls[mc.primitive_type])!=0)
                    num_draw_calls += 1
                }
            }
        }
    }
    // log.debugf("num_draw_calls: %d", num_draw_calls)
    
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

        render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, &state.depth_stencil_target_info)
        {
            sdl.BindGPUGraphicsPipeline(render_pass, state.pipeline_triangle_list)
            assert(state.draw_calls[meshes.GPU_Primitive_Type.TRIANGLELIST]!=nil)
            for draw in state.draw_calls[meshes.GPU_Primitive_Type.TRIANGLELIST]
            {
                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = state.vertex_buffer, offset = draw.vertex_buffer_offset}, 1)
                sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = state.index_buffer, offset = draw.index_buffer_offset}, draw.index_buffer_stride==2?._16BIT:._32BIT)
                ubo := Uniform_Buffer_Object{
                    mvp = proj_matrix * view_matrix * draw.model_matrix,
                    model = draw.model_matrix,
                    view = view_matrix,
                    proj = proj_matrix,
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
                sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{
                        texture = default_texture,
                        sampler = state.sampler,
                    },
                    1
                )
                sdl.DrawGPUIndexedPrimitives(
                    render_pass = render_pass,
                    num_indices = draw.index_buffer_length,
                    num_instances = 1,
                    first_index = 0,
                    vertex_offset = 0,
                    first_instance = 0,
                )
            }

            sdl.BindGPUGraphicsPipeline(render_pass, state.pipeline_line_list)
            assert(state.draw_calls[meshes.GPU_Primitive_Type.LINELIST]!=nil)
            for draw in state.draw_calls[meshes.GPU_Primitive_Type.LINELIST]
            {
                // log.warnf("line draw: {}", draw)
                sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = state.vertex_buffer, offset = draw.vertex_buffer_offset}, 1)
                sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = state.index_buffer, offset = draw.index_buffer_offset}, draw.index_buffer_stride==2?._16BIT:._32BIT)
                ubo := Uniform_Buffer_Object{
                    mvp = proj_matrix * view_matrix * draw.model_matrix,
                    model = draw.model_matrix,
                    view = view_matrix,
                    proj = proj_matrix,
                }
                sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))
                sdl.DrawGPUPrimitives(
                    render_pass = render_pass,
                    num_vertices = draw.index_buffer_length,
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

schedule_upload_to_gpu_buffer :: proc (source: []$E, gpu_buffer_region: sdl.GPUBufferRegion)
{
    // assert(source!=nil)
    assert(gpu_buffer_region.buffer!=nil)

    dat := UploadToGPUBuffer_Queue_Data{
        transfer_buffer_offset = state.vertex_transfer_buffer_offset,
        size = app.num_bytes_of_u32(source),
        source = raw_data(source),
        gpu_buffer_region = gpu_buffer_region,
    }
    append(&gpu_mesh_buffer_transfer_queue, dat)
    state.vertex_transfer_buffer_offset += dat.size

    assert((dat.size+dat.transfer_buffer_offset)<=state.vertex_transfer_buffer_offset, "this GPU buffer is too small")
    log.debugf("[schedule_upload_to_gpu_buffer()] scheduled: {}", dat)
}
schedule_upload_to_gpu_texture :: proc (source: []$E, pixels_per_row: u32, rows_per_layer: u32, gpu_texture_region: ^sdl.GPUTextureRegion)
{
    // assert(source!=nil)
    assert(gpu_texture_region!=nil)
    assert(pixels_per_row!=0)
    assert(rows_per_layer!=0)

    dat := UploadToGPUTexture_Queue_Data{
        transfer_buffer_offset = state.texture_transfer_buffer_offset,
        size = app.num_bytes_of_u32(source),
        source = raw_data(source),
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_texture_region = gpu_texture_region,
    }
    append(&gpu_texture_buffer_transfer_queue, dat)
    state.texture_transfer_buffer_offset += dat.size

    assert((dat.size+dat.transfer_buffer_offset)<=state.texture_transfer_buffer_offset, "this GPU buffer is too small")
    log.debugf("[schedule_upload_to_gpu_texture()] scheduled: {}", dat)
}
schedule_upload_to_gpu_texture_rawptr :: proc (source: rawptr, pixels_per_row: u32, rows_per_layer: u32, size: u32, gpu_texture_region: ^sdl.GPUTextureRegion)
{
    assert(source!=nil)
    assert(gpu_texture_region!=nil)
    assert(pixels_per_row!=0)
    assert(rows_per_layer!=0)

    dat := UploadToGPUTexture_Queue_Data{
        transfer_buffer_offset = state.texture_transfer_buffer_offset,
        size = size,
        source = source,
        pixels_per_row = pixels_per_row,
        rows_per_layer = rows_per_layer,
        gpu_texture_region = gpu_texture_region,
    }
    append(&gpu_texture_buffer_transfer_queue, dat)
    state.texture_transfer_buffer_offset += dat.size

    assert((dat.size+dat.transfer_buffer_offset)<=state.texture_transfer_buffer_offset, "this GPU buffer is too small")
    log.debugf("[schedule_upload_to_gpu_texture_rawptr()] scheduled: {}", dat)
}

create_mesh_components_from_file :: proc(file_name: string, allocator := context.allocator) -> (all_mesh_components: [][]game.Mesh_Component, gltf_mesh_nodes: []meshes.GLTF_Mesh_Node) {
    gltf_meshes: []meshes.GLTF_Mesh
    gltf_mesh_nodes, gltf_meshes = meshes.load_mesh_data_from_file(file_name, allocator)
    mesh_components := create_mesh_components(gltf_meshes, allocator)
    return mesh_components, gltf_mesh_nodes
}

@(require_results)
create_mesh_components :: proc(gltf_meshes: []meshes.GLTF_Mesh, allocator := context.allocator) -> [][]game.Mesh_Component {
    num_meshes := len(gltf_meshes)
    all_mesh_components := make([][]game.Mesh_Component, num_meshes, allocator)

    mesh_index := 0
    for gltf_mesh in gltf_meshes {
        num_sub_meshes := len(gltf_mesh)
        mesh_components := make([]game.Mesh_Component, num_sub_meshes, allocator)

        sub_mesh_index := 0
        for gltf_sub_mesh in gltf_mesh {
            log.debugf("len(vertex_data): {}, len(index_data): {}", len(gltf_sub_mesh.vertex_data), len(gltf_sub_mesh.index_data))

            mesh_vertex_buffer_pos := state.vertex_buffer_offset
            schedule_upload_to_gpu_buffer(
                source = gltf_sub_mesh.vertex_data,
                gpu_buffer_region = sdl.GPUBufferRegion{
                    buffer = state.vertex_buffer,
                    offset = mesh_vertex_buffer_pos,
                    size = app.num_bytes_of_u32(gltf_sub_mesh.vertex_data),
                },
            )
            state.vertex_buffer_offset += app.num_bytes_of_u32(gltf_sub_mesh.vertex_data)

            mesh_index_buffer_pos := state.index_buffer_offset
            num_indices := app.num_bytes_of_u32(gltf_sub_mesh.index_data) / u32(gltf_sub_mesh.index_stride)
            gpu_buffer_region := sdl.GPUBufferRegion{
                buffer = state.index_buffer,
                offset = mesh_index_buffer_pos,
                size = app.num_bytes_of_u32(gltf_sub_mesh.index_data),
            }
            schedule_upload_to_gpu_buffer(
                source = gltf_sub_mesh.index_data,
                gpu_buffer_region = gpu_buffer_region,
            )
            state.index_buffer_offset += gpu_buffer_region.size
            
            mesh_components[sub_mesh_index] = game.Mesh_Component{
                primitive_type = meshes.GPU_Primitive_Type.TRIANGLELIST,
                
                index_buffer_offset = mesh_index_buffer_pos,
                index_buffer_stride = gltf_sub_mesh.index_stride,
                index_buffer_length = num_indices,
                
                vertex_buffer_offset = mesh_vertex_buffer_pos,
                vertex_buffer_type = type_of(gltf_sub_mesh.vertex_data[0]),
                vertex_buffer_length = u32(len(gltf_sub_mesh.vertex_data)),
            }
            sub_mesh_index += 1
        }

        all_mesh_components[mesh_index] = mesh_components
        mesh_index += 1
    }

    log.debugf("all_mesh_components: {}", all_mesh_components)
    return all_mesh_components
}
