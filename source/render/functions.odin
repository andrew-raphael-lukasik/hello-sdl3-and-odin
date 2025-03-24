package render
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import cgltf "vendor:cgltf"


num_bytes_of :: proc (source: ^[]$E) -> int { return len(source) * size_of(source[0]) }

load_shader :: proc (device: ^sdl.GPUDevice, code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32, num_samplers: u32) -> ^sdl.GPUShader
{
    return sdl.CreateGPUShader(device, sdl.GPUShaderCreateInfo{
        code_size = len(code),
        code = raw_data(code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = stage,
        num_uniform_buffers = num_uniform_buffers,
        num_samplers = num_samplers,
    })
}

transfer_buffer_queue_append :: proc (source: ^[]$E, gpu_buffer_region: ^sdl.GPUBufferRegion, gpu_texture_region: ^sdl.GPUTextureRegion,)
{
    offset := 0  
    {
        l := len(transfer_buffer_queue)
        if l!=0
        {
            offset = transfer_buffer_queue[l-1].transfer_buffer_offset + transfer_buffer_queue[l-1].size
        }
    }
    append(&transfer_buffer_queue, TransferBufferQueueItem{
        transfer_buffer_offset = offset,
        size = num_bytes_of(source),
        source = raw_data(source^),
        gpu_buffer_region = gpu_buffer_region,
        gpu_texture_region = gpu_texture_region,
    })
}

create_texture :: proc ( gpu: ^sdl.GPUDevice ) -> ^sdl.GPUTexture
{
    // image := sdl_image.Load("checker")
    image := sdl.Surface{
        flags = { sdl.SurfaceFlag.PREALLOCATED },
        format = sdl.PixelFormat.RGBA32,
        w = 4,
        h = 4,
        pitch = 4*4,
        pixels = &image_pixels,//sdl.aligned_alloc(512,16),
        refcount = 0,
        reserved = nil,
    }
    texture := sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = sdl.GPUTextureFormat.R8G8B8A8_UNORM,
        usage = { sdl.GPUTextureUsageFlag.SAMPLER },
        width = 4,
        height = 4,
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    return texture;
}
