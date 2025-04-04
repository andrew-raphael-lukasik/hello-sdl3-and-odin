package textures
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "core:log"
import "core:os"
import "core:strings"
import "core:mem"


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

load_texture_file :: proc (gpu: ^sdl.GPUDevice, path: string) -> (texture: ^sdl.GPUTexture, surface: ^sdl.Surface, ok: bool)
{
    if !os.exists(string(path))
    {
        log.errorf("File does not exist: {}", path)
        return nil, nil, false
    }

    surface = sdl_image.Load(strings.clone_to_cstring(path, context.temp_allocator))
    log.debugf("[load_texture_file], texture loaded successfully: {}, surface: {}", path, surface)

    // flip it vertically
    {
        w := int(surface.w);
        h := int(surface.h);
        pitch := int(surface.pitch)
        data := uintptr(surface.pixels)
        row := make([]u8, pitch, context.temp_allocator); 
        row_ptr := raw_data(row)
        for y := 0 ; y < h/2 ; y += 1 {
            top := uintptr(pitch*y);
            bottom := uintptr((h-1-y)*pitch);
            mem.copy(row_ptr, rawptr(data+top), pitch);
            mem.copy(rawptr(data+top), rawptr(data+bottom), pitch);
            mem.copy(rawptr(data+bottom), row_ptr, pitch);
        }
    }

    cpu_format := sdl.PixelFormat.RGBA32
    gpu_format := sdl.GPUTextureFormat.R8G8B8A8_UNORM

    if surface.format!=cpu_format
    {
        log.debugf("[load_texture_file] converting surface to {} format...", cpu_format)
        new := sdl.ConvertSurface(surface, cpu_format)
        sdl.DestroySurface(surface)
        surface = new
        log.debugf("[load_texture_file] surface converted: {}", surface)
    }

    texture = sdl.CreateGPUTexture(gpu, sdl.GPUTextureCreateInfo{
        type = sdl.GPUTextureType.D2,
        format = gpu_format,
        usage = { sdl.GPUTextureUsageFlag.SAMPLER },
        width = u32(surface.w),
        height = u32(surface.h),
        layer_count_or_depth = 1,
        num_levels = 1,
    })
    return texture, surface, true
}
