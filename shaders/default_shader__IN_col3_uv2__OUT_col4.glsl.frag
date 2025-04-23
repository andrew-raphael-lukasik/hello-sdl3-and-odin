#version 460

layout(set=2, binding=0)uniform sampler2D tex_sampler;
layout(location=0) in vec3 color;
layout(location=1) in vec2 uv;
layout(location=0) out vec4 OUT;

void main ()
{
    OUT = texture(tex_sampler, uv) * vec4(color,1);
}
