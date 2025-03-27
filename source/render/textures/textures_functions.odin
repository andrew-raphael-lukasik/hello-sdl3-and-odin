package textures
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"


create_default_texture :: proc (gpu: ^sdl.GPUDevice) -> ^sdl.GPUTexture
{
    texture := sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = sdl.GPUTextureFormat.R8G8B8A8_UNORM,
        usage = { sdl.GPUTextureUsageFlag.SAMPLER },
        width = 4,
        height = 4,
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    return texture
}
