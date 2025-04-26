package game
import sdl "vendor:sdl3"
import "../render/meshes"


Entity :: struct
{
    index, version: u32
}

Component :: union
{
    Transform_Component,
    Camera_Component,
    Mesh_Component,
    Rotation_Component,
    Label_Component
}

Mesh_Component :: struct
{
    primitive_type: meshes.GPU_Primitive_Type,
    index_buffer_element_size: sdl.GPUIndexElementSize,
    index_buffer_offset: u32,
    vertex_buffer_offset: u32,
    vertex_buffer_num_indices: u32,
}

Transform_Component :: struct
{
    matrix3x3: matrix[3,3]f32,
    translation: [3]f32,
}

Camera_Component :: struct
{
    
}

Rotation_Component :: struct
{
    axis: [3]f32,
    speed: f32,
    offset: f32,
}

Label_Component :: struct
{
    value: string
}
