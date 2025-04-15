package meshes
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "vendor:cgltf"
import "core:log"
import "../gltf2"
import "../../game"


@(require_results)
load_mesh_data_from_file :: proc(file_name: string, allocator := context.allocator) -> ([][]Vertex_Data, [][]u16) {
    mesh_data, error := gltf2.load_from_file(file_name)
    switch err in error
    {
        case gltf2.JSON_Error: log.error("gltf2.JSON_Error")
        case gltf2.GLTF_Error: log.error("gltf2.GLTF_Error")
    }

    defer gltf2.unload(mesh_data)

    vertex_data := make([dynamic][]Vertex_Data, allocator)
    index_data := make([dynamic][]u16, allocator)

    for mesh in mesh_data.meshes
    {
        indices: [dynamic]u16
        positions: [dynamic][3]f32
        uvs: [dynamic][2]f32
        colors: [dynamic][3]f32

        for primitive in mesh.primitives
        {
            indices_accessor_index, primitive_indices_exists := primitive.indices.?
            if !primitive_indices_exists
            {
                log.errorf("indices_accessor_index not present")
                continue
            }

            indices_accessor := mesh_data.accessors[indices_accessor_index]
            switch indices_accessor.component_type
            {
                case .Byte:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]byte)
                    for val in buf do append(&indices, u16(val))
                case .Unsigned_Byte:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u8)
                    for val in buf do append(&indices, u16(val))
                case .Short:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]i16)
                    for val in buf do append(&indices, u16(val))
                case .Unsigned_Short:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u16)
                    for val in buf do append(&indices, u16(val))
                case .Unsigned_Int:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]u32)
                    for val in buf do append(&indices, u16(val))
                case .Float:
                    buf := gltf2.buffer_slice(mesh_data, indices_accessor_index).([]f32)
                    for val in buf do append(&indices, u16(val))
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
        vertices := make([]Vertex_Data, num_vertices)
        for i:u32 = 0 ; i<u32(len(vertices)) ; i+=1 {
            vertices[i] = Vertex_Data{
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
    }

    return vertex_data[:], index_data[:]
}
