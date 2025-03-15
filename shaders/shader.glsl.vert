#version 460

layout(set=1, binding=0) uniform UBO {
    mat4 mvp;
};
layout(location=0) out vec3 vertex_color;

void main ()
{
    // clip space
    vec4 position;
    if(gl_VertexIndex==0)
    {
        position = vec4(-0.9, -0.9, 0, 1);
        vertex_color = vec3(1, 1, 0);
    }
    else if(gl_VertexIndex==1)
    {
        position = vec4(0, 0.9, 0, 1);
        vertex_color = vec3(0, 1, 1);
    }
    else if(gl_VertexIndex==2)
    {
        position = vec4(0.9, -0.9, 0, 1);
        vertex_color = vec3(1, 0, 1);
    }

    gl_Position = mvp * position;
}
