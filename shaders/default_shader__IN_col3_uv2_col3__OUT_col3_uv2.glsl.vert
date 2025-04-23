#version 460

layout(set=1, binding=0) uniform UniformBufferObject {
    mat4 mvp;
    mat4 model;
    mat4 view;
    mat4 proj;
};
layout(location=0) in vec3 pos;
layout(location=1) in vec2 uv;
layout(location=2) in vec3 col;
layout(location=0) out vec3 COLOR;
layout(location=1) out vec2 UV;

void main ()
{
    gl_Position = mvp * vec4(pos, 1);
    COLOR = col;
    UV = uv;
}
