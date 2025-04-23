package meshes
import sdl "vendor:sdl3"
import "../../app"


default_quad_vertices : []Vertex_Data__pos3_uv2_col3 = {
    {pos = {-0.5, -0.5, 0},    uv = {0, 0},    col = {1, 1, 1}},//BL
    {pos = {-0.5, 0.5, 0},     uv = {0, 1},    col = {1, 1, 1}},//TL
    {pos = {0.5, 0.5, 0},      uv = {1, 1},    col = {1, 1, 1}},//TR
    {pos = {0.5, -0.5, 0},     uv = {1, 0},    col = {1, 1, 1}},//BR
}
default_quad_vertices_num_bytes := app.num_bytes_of_u32(&default_quad_vertices)
default_quad_indices := []u16 { 0, 1, 2,   0, 2, 3, }
default_quad_indices_num_bytes := app.num_bytes_of_u32(&default_quad_indices)

axis_vertices : []Vertex_Data__pos3_col3 = {
    {pos = {0, 0, 0}, col = {1, 0, 0}},
    {pos = {1, 0, 0}, col = {1, 0, 0}},
    {pos = {0, 0, 0}, col = {0, 1, 0}},
    {pos = {0, 1, 0}, col = {0, 1, 0}},
    {pos = {0, 0, 0}, col = {0, 0, 1}},
    {pos = {0, 0, 1}, col = {0, 0, 1}},
}
axis_vertices_num_bytes := app.num_bytes_of_u32(&axis_vertices)
axis_indices : []u16 = {0, 1, 2, 3, 4, 5}
axis_indices_num_bytes := app.num_bytes_of_u32(&axis_indices)

vertex_attrs__pos3 := []sdl.GPUVertexAttribute{
    {
        location = 0,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, pos)),
    }
}
vertex_attrs__pos3_uv2 := []sdl.GPUVertexAttribute{
    {
        location = 0,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, pos)),
    },
    {
        location = 1,
        buffer_slot = 0,
        format = .FLOAT2,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, uv)),
    }
}
vertex_attrs__pos3_col3 := []sdl.GPUVertexAttribute{
    {
        location = 0,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, pos)),
    },
    {
        location = 2,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, col)),
    },
}
vertex_attrs__pos3_uv2_col3 := []sdl.GPUVertexAttribute{
    {
        location = 0,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, pos)),
    },
    {
        location = 1,
        buffer_slot = 0,
        format = .FLOAT2,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, uv)),
    },
    {
        location = 2,
        buffer_slot = 0,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_Data__pos3_uv2_col3, col)),
    },
}
