package meshes
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "vendor:cgltf"
import "core:log"
import "../gltf2"


@(require_results)
load_mesh_data_from_file :: proc(file_name: string, allocator := context.allocator) -> ([][]Vertex_Data__pos3_uv2_col3, [][]byte, []sdl.GPUIndexElementSize, []GLTF_Mesh_Object_Info) {
    mesh_data, error := gltf2.load_from_file(file_name)
    switch err in error
    {
        case gltf2.JSON_Error: log.error("gltf2.JSON_Error")
        case gltf2.GLTF_Error: log.error("gltf2.GLTF_Error")
    }

    defer gltf2.unload(mesh_data)

    vertex_data := make([dynamic][]Vertex_Data__pos3_uv2_col3, allocator)
    index_data := make([dynamic][]byte, allocator)
    index_size_data := make([dynamic]sdl.GPUIndexElementSize, allocator)

    for mesh in mesh_data.meshes
    {
        indices: [dynamic]byte
        positions: [dynamic][3]f32
        uvs: [dynamic][2]f32
        colors: [dynamic][3]f32
        index_size: sdl.GPUIndexElementSize

        for primitive in mesh.primitives
        {
            indices_accessor_index, primitive_indices_exists := primitive.indices.?
            if !primitive_indices_exists
            {
                log.errorf("indices_accessor_index not present")
                continue
            }

            indices_accessor := mesh_data.accessors[indices_accessor_index]
            #partial switch indices_accessor.component_type
            {
                case .Unsigned_Short:
                    index_size = sdl.GPUIndexElementSize._16BIT
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u16)
                    for val in buf
                    {
                        b2 := transmute([2]byte) val
                        append_elems(&indices, b2[0], b2[1])
                    }
                case .Unsigned_Int:
                    index_size = sdl.GPUIndexElementSize._16BIT
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u32)
                    for val in buf
                    {
                        b4 := transmute([4]byte) val
                        append_elems(&indices, b4[0], b4[1], b4[2], b4[3])
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
        }

        num_vertices := u32(len(positions))
        vertices := make([]Vertex_Data__pos3_uv2_col3, num_vertices)
        for i:u32 = 0 ; i<u32(len(vertices)) ; i+=1 {
            vertices[i] = Vertex_Data__pos3_uv2_col3{
                pos = {0, 0, 0},
                uv =  {0, 0},
                col = {1, 1, 1},
            }
        }
        for i:u32 = 0 ; i<u32(len(positions)) ; i+=1 {
            vertices[i].pos = positions[i]
        }
        for i:u32 = 0 ; i<u32(len(uvs)) ; i+=1 {
            vertices[i].uv = uvs[i]
        }
        for i:u32 = 0 ; i<u32(len(colors)) ; i+=1 {
            vertices[i].col = colors[i]
        }
        
        append(&vertex_data, vertices)
        append(&index_data, indices[:])
        append(&index_size_data, index_size)
    }

    mesh_objects := make_dynamic_array([dynamic]GLTF_Mesh_Object_Info)
    for node in mesh_data.nodes {
        if node_mesh, is_mesh := node.mesh.?; is_mesh {
            obj := GLTF_Mesh_Object_Info{
                mesh_index = node_mesh,
                translation = node.translation,
                scale = node.scale,
                rotation = node.rotation,
            }
            append(&mesh_objects, obj)
        }
    }

    return vertex_data[:], index_data[:], index_size_data[:], mesh_objects[:]
}
