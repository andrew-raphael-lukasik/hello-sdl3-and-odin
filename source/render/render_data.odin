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
default_shader_vert: ^sdl.GPUShader
default_shader_frag: ^sdl.GPUShader
transfer_buffer_queue := make([dynamic]Transfer_Buffer_Queue_Item, 0, 32)
