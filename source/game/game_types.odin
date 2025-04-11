package game
import sdl "vendor:sdl3"


Entity :: struct
{
    index, version: u32
}

Component :: union
{
    Transform_Component,
    Camera_Component,
    Mesh_Component,
    Rotation_Component
}

Mesh_Component :: struct
{
    index_buffer_element_size: sdl.GPUIndexElementSize,
    index_buffer_offset: u32,
    vertex_buffer_offset: u32,
    vertex_buffer_num_indices: u32,
}

Transform_Component :: struct
{
    value: matrix[4,4]f32
}

Camera_Component :: struct
{
    
}

Rotation_Component :: struct
{
    axis: [3]f32,
    speed: f32
}
