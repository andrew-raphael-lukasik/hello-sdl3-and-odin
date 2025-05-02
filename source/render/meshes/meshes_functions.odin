package meshes
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "vendor:cgltf"
import "core:log"
import "core:mem"
import "../gltf2"


@(require_results)
load_mesh_data_from_file :: proc(file_name: string, allocator := context.allocator) -> ([]GLTF_Mesh_Node, []GLTF_Mesh) {
    mesh_data, error := gltf2.load_from_file(file_name)
    defer gltf2.unload(mesh_data)
    switch err in error
    {
        case gltf2.JSON_Error: log.error("gltf2.JSON_Error")
        case gltf2.GLTF_Error: log.error("gltf2.GLTF_Error")
    }

    num_meshes := len(mesh_data.meshes)
    gltf_meshes := make([]GLTF_Mesh, num_meshes, allocator)

    mesh_id := 0
    for mesh in mesh_data.meshes {
        num_sub_meshes := len(mesh.primitives)
        gltf_mesh := make(GLTF_Mesh, num_sub_meshes, context.allocator)
        vertex_data := make([]Vertex_Data__pos3_uv2_col3, num_sub_meshes, allocator)
        index_data := make([]byte, num_sub_meshes, allocator)

        sub_mesh_id := 0
        for primitive in mesh.primitives
        {
            if primitive.mode!=.Triangles {
                log.errorf("Unsupported primitive type: {}", primitive.mode)
                continue
            }

            indices: [dynamic]byte
            positions: [dynamic][3]f32
            uvs: [dynamic][2]f32
            colors: [dynamic][3]f32
            index_size: sdl.GPUIndexElementSize

            indices_accessor_index, primitive_indices_exists := primitive.indices.?
            if !primitive_indices_exists
            {
                log.errorf("indices_accessor_index not present")
                continue
            }

            indices_accessor := mesh_data.accessors[indices_accessor_index]
            #partial switch indices_accessor.component_type
            {
                case .Unsigned_Short:// u16
                    index_size = sdl.GPUIndexElementSize._16BIT
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u16)
                    for val in buf {
                        for b in mem.any_to_bytes(val) {
                            append(&indices, b)
                        }
                    }
                case .Unsigned_Int:// u32
                    index_size = sdl.GPUIndexElementSize._32BIT
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u32)
                    for val in buf {
                        for b in mem.any_to_bytes(val) {
                            append(&indices, b)
                        }
                    }
            }

            for attribute_name, accessor_index in primitive.attributes
            {
                primitive_accessor := mesh_data.accessors[accessor_index]
                switch attribute_name
                {
                    case "POSITION":
                        #partial switch primitive_accessor.type
                        {
                            case .Vector3:
                                buf := gltf2.buffer_slice(mesh_data, accessor_index).([][3]f32)
                                for val in buf do append(&positions, val)
                                case: log.errorf("{} case not implemented, according to specs https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html", primitive_accessor.type)
                        }
                    case "NORMAL":
                        log.warnf("attribute {} {} not implemented", attribute_name, primitive_accessor.type)
                    case "TANGENT":
                        log.warnf("attribute {} {} not implemented", attribute_name, primitive_accessor.type)
                    case "TEXCOORD_0":
                        #partial switch primitive_accessor.type
                        {
                            case .Vector2:
                                buf := gltf2.buffer_slice(mesh_data, accessor_index).([][2]f32)
                                for val in buf do append(&uvs, val)
                                case: log.errorf("{} case not implemented, according to specs https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html", primitive_accessor.type)
                        }
                    case "COLOR_0":
                        #partial switch primitive_accessor.type
                        {
                            case .Vector3:
                                buf := gltf2.buffer_slice(mesh_data, accessor_index).([][3]f32)
                                for val in buf do append(&colors, val)
                            case .Vector4:
                                buf := gltf2.buffer_slice(mesh_data, accessor_index).([][4]f32)
                                for val in buf do append(&colors, [3]f32{val.r, val.g, val.b})
                            case: log.errorf("{} case not implemented, according to specs https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html", primitive_accessor.type)
                        }
                }
            }

            num_vertices := u32(len(positions))
            vertices := make([]Vertex_Data__pos3_uv2_col3, num_vertices)
            for i in 0..<len(vertices) {
                vertices[i] = Vertex_Data__pos3_uv2_col3{
                    pos = {0, 0, 0},
                    uv =  {0, 0},
                    col = {1, 1, 1},
                }
            }
            for i in 0..<len(positions) {
                vertices[i].pos = positions[i]
            }
            for i in 0..<len(uvs) {
                vertices[i].uv = uvs[i]
            }
            for i in 0..<len(colors) {
                vertices[i].col = colors[i]
            }
            
            gltf_mesh[sub_mesh_id] = GLTF_Sub_Mesh{
                vertex_data = vertices,
                index_data = indices[:],
                index_stride = index_size==._16BIT ? 2 : 4,
            }
            sub_mesh_id += 1
        }

        gltf_meshes[mesh_id] = gltf_mesh
        mesh_id += 1
    }

    mesh_objects := make_dynamic_array([dynamic]GLTF_Mesh_Node)
    for node in mesh_data.nodes {
        if node_mesh, is_mesh := node.mesh.?; is_mesh {
            obj := GLTF_Mesh_Node{
                mesh_index = node_mesh,
                translation = node.translation,
                scale = node.scale,
                rotation = node.rotation,
            }
            append(&mesh_objects, obj)
        }
    }

    return mesh_objects[:], gltf_meshes
}

bytes_to_u16_slice :: proc(bytes: []byte, little_endian: bool = true, allocator := context.allocator) -> []u16 {
    stride := size_of(u16)
    count := len(bytes) / stride;
    result := make([]u16, count, allocator);
    if little_endian {
        for i in 0..<count {
            b0 := bytes[i*stride];
            b1 := bytes[i*stride + 1];
            result[i] = u16(b0) | (u16(b1) << 8);
        }
    }
    else {
        for i in 0..<count {
            b0 := bytes[i*stride];
            b1 := bytes[i*stride + 1];
            result[i] = (u16(b0) << 8) | u16(b1);
        }
    }
    return result;
}

bytes_to_u32_slice :: proc(bytes: []byte, little_endian: bool = true, allocator := context.allocator) -> []u32 {
    stride := size_of(u32)
    count := len(bytes) / stride;
    result := make([]u32, count, allocator);
    if little_endian {
        for i in 0..<count {
            b0 := bytes[i*stride];
            b1 := bytes[i*stride + 1];
            b2 := bytes[i*stride + 2];
            b3 := bytes[i*stride + 3];
            result[i] = u32(b0) | (u32(b1) << 8) | (u32(b2) << 16) | (u32(b3) << 24);
        }
    }
    else {
        for i in 0..<count {
            b0 := bytes[i*2];
            b1 := bytes[i*2 + 1];
            b2 := bytes[i*2 + 2];
            b3 := bytes[i*2 + 3];
            result[i] = (u32(b0) << 24) | (u32(b1) << 16) | (u32(b2) << 8) | u32(b3);
        }
    }
    return result;
}
