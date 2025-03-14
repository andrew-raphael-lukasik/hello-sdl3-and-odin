#version 460

layout(location=0) out vec3 vertex_color;

void main ()
{
    // clip space
    if(gl_VertexIndex==0)
    {
        gl_Position = vec4(-0.9, -0.9, 0, 1);
        vertex_color = vec3(1, 1, 0);
    }
    else if(gl_VertexIndex==1)
    {
        gl_Position = vec4(0, 0.9, 0, 1);
        vertex_color = vec3(0, 1, 1);
    }
    else if(gl_VertexIndex==2)
    {
        gl_Position = vec4(0.9, -0.9, 0, 1);
        vertex_color = vec3(1, 0, 1);
    }
}
