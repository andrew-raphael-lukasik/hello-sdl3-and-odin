package meshes
import sdl "vendor:sdl3"
import "../../app"


default_quad_vertices : []Vertex_Data = {
    { pos = {-0.5, -0.5, 0},    col = {1, 1, 1},    uv = {0, 0}},//BL
    { pos = {-0.5, 0.5, 0},     col = {0, 1, 1},    uv = {0, 1}},//TL
    { pos = {0.5, 0.5, 0},      col = {1, 1, 1},    uv = {1, 1}},//TR
    { pos = {0.5, -0.5, 0},     col = {1, 1, 1},    uv = {1, 0}},//BR
}
default_quad_vertices_num_bytes := u32(app.num_bytes_of(&default_quad_vertices))

default_quad_indices := []u16 { 0, 1, 2,   0, 2, 3, }
default_quad_indices_num_bytes := u32(app.num_bytes_of(&default_quad_indices))

default_quad_vert_attrs := []sdl.GPUVertexAttribute{
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
