#version 460

layout(location=0) in vec3 vertex_color;
layout(location=0) out vec3 color;

void main ()
{
    color = vertex_color;
}
