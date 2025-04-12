package render
import sdl "vendor:sdl3"


Uniform_Buffer_Object :: struct {
    mvp: matrix[4,4]f32,
    model: matrix[4,4]f32,
    view: matrix[4,4]f32,
    proj: matrix[4,4]f32,
}

Renderer_State :: struct
{
    pipeline: ^sdl.GPUGraphicsPipeline,
    sampler: ^sdl.GPUSampler,

    vertex_buffer: ^sdl.GPUBuffer,
    vertex_buffer_offset: u32,
    
    index_buffer: ^sdl.GPUBuffer,
    index_buffer_offset: u32,

    vertex_transfer_buffer_offset: u32,
    texture_transfer_buffer_offset: u32,

    draw_calls: [dynamic]Draw_Call_Data,
}

UploadToGPUBuffer_Queue_Data :: struct
{
    transfer_buffer_offset: u32,
    size: u32,
    source: rawptr,
    gpu_buffer_region: ^sdl.GPUBufferRegion,
}
UploadToGPUTexture_Queue_Data :: struct
{
    transfer_buffer_offset: u32,
    size: u32,
    source: rawptr,
    pixels_per_row: u32,
    rows_per_layer: u32,
    gpu_texture_region: ^sdl.GPUTextureRegion,
}

Draw_Call_Data :: struct
{
    model_matrix: matrix[4, 4]f32,

    index_buffer_element_size: sdl.GPUIndexElementSize,
    index_buffer_offset: u32,

    vertex_buffer_offset: u32,
    vertex_buffer_num_indices: u32,
}
