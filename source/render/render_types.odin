package render
import sdl "vendor:sdl3"
import "meshes"


Uniform_Buffer_Object :: struct {
    mvp: matrix[4,4]f32,
    model: matrix[4,4]f32,
    view: matrix[4,4]f32,
    proj: matrix[4,4]f32,
}

Renderer_State :: struct
{
    pipeline_triangle_list: ^sdl.GPUGraphicsPipeline,
    pipeline_line_list: ^sdl.GPUGraphicsPipeline,
    sampler: ^sdl.GPUSampler,
    depth_texture: ^sdl.GPUTexture,
    depth_texture_format: sdl.GPUTextureFormat,
    depth_stencil_target_info: sdl.GPUDepthStencilTargetInfo,

    vertex_buffer: ^sdl.GPUBuffer,
    vertex_buffer_offset: u32,
    
    index_buffer: ^sdl.GPUBuffer,
    index_buffer_offset: u32,

    vertex_transfer_buffer_offset: u32,
    texture_transfer_buffer_offset: u32,

    draw_calls: map[meshes.GPU_Primitive_Type][dynamic]Draw_Call_Data,
}

UploadToGPUBuffer_Queue_Data :: struct
{
    transfer_buffer_offset: u32,
    size: u32,
    source: rawptr,
    gpu_buffer_region: sdl.GPUBufferRegion,
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

    index_buffer_offset: u32,
    index_buffer_element_size: sdl.GPUIndexElementSize,
    index_buffer_num_elements: u32,

    vertex_buffer_offset: u32,
}
