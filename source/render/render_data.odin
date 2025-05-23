package render
import sdl "vendor:sdl3"
import "core:c"


gpu: ^sdl.GPUDevice
window_size: [2]c.int = {1280, 780}
window: ^sdl.Window
state: Renderer_State
default_texture: ^sdl.GPUTexture
default_shader_vert: ^sdl.GPUShader
default_shader_frag: ^sdl.GPUShader
default_shader_line_vert: ^sdl.GPUShader
default_shader_line_frag: ^sdl.GPUShader
gpu_mesh_buffer_transfer_queue := make([dynamic]UploadToGPUBuffer_Queue_Data, 0, 32)
gpu_texture_buffer_transfer_queue := make([dynamic]UploadToGPUTexture_Queue_Data, 0, 32)
