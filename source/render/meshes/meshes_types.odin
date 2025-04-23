package meshes


Vertex_Data__pos3 :: struct
{
    pos: [3]f32
}
Vertex_Data__pos3_uv2 :: struct
{
    pos: [3]f32,
    uv: [2]f32,
}
Vertex_Data__pos3_col3 :: struct
{
    pos: [3]f32,
    col: [3]f32,
}
Vertex_Data__pos3_uv2_col3 :: struct
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

GPU_Primitive_Type :: enum u8 {
	TRIANGLELIST,  /**< A series of separate triangles. */
	// TRIANGLESTRIP, /**< A series of connected triangles. */
	LINELIST,      /**< A series of separate lines. */
	// LINESTRIP,     /**< A series of connected lines. */
	// POINTLIST,     /**< A series of separate points. */
}
