set project_name=hello-sdl3
set build_name=win64-debug
set build_path=%~dp0build\%build_name%

call build_preprocessor.bat
if %errorlevel% neq 0 exit /b 1

build_preprocessor.exe
if %errorlevel% neq 0 exit /b 1

glslc ./shaders/default_shader.glsl.vert -o %build_path%/data/default_shader.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/default_shader.glsl.frag -o %build_path%/data/default_shader.spv.frag
if %errorlevel% neq 0 exit /b 1

odin build ./source/ -debug -out:%build_path%\bin\%project_name%.exe
if %errorlevel% neq 0 exit /b 1

if "%~1" == "run" (
    cd build
    cd %build_name%
    cd bin
    %project_name%.exe
)
