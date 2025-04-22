package meshes


Vertex_Data :: struct
{
    pos: [3]f32,
    uv: [2]f32,
    col: [3]f32,
}

GLTF_Mesh_Object_Info :: struct {
    mesh_index: u32,
    // transform: matrix[4,4]f32,
    translation: [3]f32,
    scale: [3]f32,
    rotation: quaternion128,
}
