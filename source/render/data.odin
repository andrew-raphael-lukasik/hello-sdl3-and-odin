package render
import sdl "vendor:sdl3"
import "core:math/linalg"


gpu: ^sdl.GPUDevice
window_width:i32 = 1280
window_height:i32 = 780
window: ^sdl.Window
pipeline: ^sdl.GPUGraphicsPipeline
sampler: ^sdl.GPUSampler
proj_matrix := linalg.matrix4_perspective_f32(70, 1.0, 0.001, 1000.0)
vertex_buffer_gpu: ^sdl.GPUBuffer
index_buffer_gpu: ^sdl.GPUBuffer
default_texture: ^sdl.GPUTexture

vert_shader_spv := #load("../../shaders_compiled/shader.spv.vert")
frag_shader_spv := #load("../../shaders_compiled/shader.spv.frag")

vertices : []Vertex_Data = {
    { pos = {-0.5, -0.5, 0}, col = {1, 1, 0}, uv = {0, 1}},//BL
    { pos = {-0.5, 0.5, 0}, col = {0, 1, 1}, uv = {0, 0}},//TL
    { pos = {0.5, 0.5, 0}, col = {1, 0, 1}, uv = {1, 0}},//TR
    { pos = {0.5, -0.5, 0}, col = {1, 1, 1}, uv = {1, 1}},//BR
}
vertices_num_bytes := u32(num_bytes_of(&vertices))

indices := []u16 {
    0, 1, 2,
    0, 2, 3,
}
indices_num_bytes := u32(num_bytes_of(&indices))

transfer_buffer_queue := make([dynamic]TransferBufferQueueItem, 0, 32)

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
    255, 0, 0, 255,
    0, 255, 0, 255,
    0, 0, 255, 255,
    255, 255, 0, 255,
    
    255, 0, 0, 255,
    0, 255, 0, 255,
    0, 0, 255, 255,
    255, 255, 0, 255,

    255, 0, 0, 255,
    0, 255, 0, 255,
    0, 0, 255, 255,
    255, 255, 0, 255,

    255, 0, 0, 255,
    0, 255, 0, 255,
    0, 0, 255, 255,
    255, 255, 0, 255,
}
