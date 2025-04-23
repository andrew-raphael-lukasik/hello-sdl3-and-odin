#version 460

layout(set=2, binding=0)uniform sampler2D tex_sampler;
layout(location=0) in vec3 color;
layout(location=0) out vec3 OUT;

void main ()
{
    OUT = color;
}
