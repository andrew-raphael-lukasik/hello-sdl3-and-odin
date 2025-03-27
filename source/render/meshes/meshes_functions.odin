package meshes
import sdl "vendor:sdl3"
import sdl_image "vendor:sdl3/image"
import "vendor:cgltf"
import "core:log"


num_bytes_of :: proc (source: ^[]$E) -> int { return len(source) * size_of(source[0]) }
