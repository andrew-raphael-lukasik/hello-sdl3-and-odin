#version 460

layout(location=0) in vec3 color;
layout(location=0) out vec3 OUT;

void main ()
{
    OUT = color;
}
