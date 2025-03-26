package render
import sdl "vendor:sdl3"


Vertex_Data :: struct
{
    pos: [3]f32,
    col: [3]f32,
    uv: [2]f32,
}

Uniform_Buffer_Object :: struct {
    mvp: matrix[4,4]f32,
    model: matrix[4,4]f32,
    view: matrix[4,4]f32,
    proj: matrix[4,4]f32,
}

Transfer_Buffer_Queue_Item :: struct
{
    transfer_buffer_offset: int,
    size: int,
    source: rawptr,
    gpu_buffer_region: ^sdl.GPUBufferRegion,
    gpu_texture_region: ^sdl.GPUTextureRegion,
}
