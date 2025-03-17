#version 460

layout(set=1, binding=0) uniform UBO {
    mat4 mvp;
};

layout(location=0) in vec3 pos;
layout(location=1) in vec3 col;
layout(location=0) out vec3 vertex_color;

void main ()
{
    gl_Position = mvp * vec4(pos, 1);
    vertex_color = col;
}
