package render
import sdl "vendor:sdl3"
import "core:math/linalg"


gpu: ^sdl.GPUDevice
window_size: [2]i32 = {1280, 780}
window: ^sdl.Window
pipeline: ^sdl.GPUGraphicsPipeline
sampler: ^sdl.GPUSampler
vertex_buffer_gpu: ^sdl.GPUBuffer
index_buffer_gpu: ^sdl.GPUBuffer
default_texture: ^sdl.GPUTexture
transfer_buffer_queue := make([dynamic]Transfer_Buffer_Queue_Item, 0, 32)

vert_shader_spv_rawdata :: #load("../../shaders_compiled/shader.spv.vert")
frag_shader_spv_rawdata :: #load("../../shaders_compiled/shader.spv.frag")
default_cube_rawdata :: #load("../../assets/default_cube.gltf")

default_quad_vertices : []Vertex_Data = {
    { pos = {-0.5, -0.5, 0},    col = {1, 1, 1},    uv = {0, 0}},//BL
    { pos = {-0.5, 0.5, 0},     col = {0, 1, 1},    uv = {0, 1}},//TL
    { pos = {0.5, 0.5, 0},      col = {1, 1, 1},    uv = {1, 1}},//TR
    { pos = {0.5, -0.5, 0},     col = {1, 1, 1},    uv = {1, 0}},//BR
}
default_quad_vertices_num_bytes := u32(num_bytes_of(&default_quad_vertices))

default_quad_indices := []u16 { 0, 1, 2,   0, 2, 3, }
default_quad_indices_num_bytes := u32(num_bytes_of(&default_quad_indices))

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

image_pixels := []u8{
    0, 0, 128, 255,         64, 0, 128, 255,        128, 0, 128, 255,       255, 0, 128, 255,
    0, 64, 128, 255,        64, 64, 128, 255,       128, 64, 128, 255,      255, 64, 128, 255,
    0, 128, 128, 255,       64, 128, 128, 255,      128, 128, 128, 255,     255, 128, 128, 255,
    0, 255, 128, 255,       64, 255, 128, 255,      128, 255, 128, 255,     255, 255, 128, 255,
}
