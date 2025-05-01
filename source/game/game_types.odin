package game
import sdl "vendor:sdl3"
import "base:runtime"
import "../render/meshes"


Entity :: struct
{
    index, version: u32
}

Transform :: struct
{
    matrix3x3: matrix[3,3]f32,
    translation: [3]f32,
}

Component :: union
{
    Camera_Component,
    Mesh_Component,
    Rotation_Component,
    Label_Component
}

Mesh_Component :: struct
{
    primitive_type: meshes.GPU_Primitive_Type,
    
    index_buffer_offset: u32,
    index_buffer_stride: u8,
    index_buffer_length: u32,
    
    vertex_buffer_offset: u32,
    vertex_buffer_type: typeid,
    vertex_buffer_length: u32,
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
