set project_name=hello-sdl3

md %~dp0shaders_compiled 2> nul
glslc ./shaders/shader.glsl.vert -o ./shaders_compiled/shader.spv.vert
glslc ./shaders/shader.glsl.frag -o ./shaders_compiled/shader.spv.frag

odin build ./source/ -debug
md %~dp0bin\debug 2> nul
move source.exe %~dp0bin\debug\%project_name%.exe
move source.pdb %~dp0bin\debug\%project_name%.pdb
copy %~dp0dlls\SDL3.dll %~dp0bin\debug\

if "%~1" == "run" (
    %~dp0bin\debug\%project_name%.exe
    @REM cd bin
    @REM %project_name%.exe
    @REM cd ..
)
