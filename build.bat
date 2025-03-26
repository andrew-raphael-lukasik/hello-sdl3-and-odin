set project_name=hello-sdl3

md %~dp0shaders_compiled 2> nul
glslc ./shaders/shader.glsl.vert -o ./shaders_compiled/shader.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/shader.glsl.frag -o ./shaders_compiled/shader.spv.frag
if %errorlevel% neq 0 exit /b 1

odin build ./source/ -debug
if %errorlevel% neq 0 exit /b 1
md %~dp0bin\debug 2> nul
move source.exe %~dp0bin\debug\%project_name%.exe
move source.pdb %~dp0bin\debug\%project_name%.pdb
copy %~dp0source\render\redistributable_bin\SDL3.dll %~dp0bin\debug\

if "%~1" == "run" (
    %~dp0bin\debug\%project_name%.exe
    @REM cd bin
    @REM %project_name%.exe
    @REM cd ..
)
