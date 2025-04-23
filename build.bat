set project_name=hello-sdl3
set build_name=win64-debug
set build_path=%~dp0build\%build_name%

call build_preprocessor.bat
if %errorlevel% neq 0 exit /b 1

build_preprocessor.exe
if %errorlevel% neq 0 exit /b 1

glslc ./shaders/default_shader__IN_col3_uv2_col3__OUT_col3_uv2.glsl.vert -o %build_path%/data/default_shader__IN_col3_uv2_col3__OUT_col3_uv2.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/default_shader__IN_col3_uv2__OUT_col4.glsl.frag -o %build_path%/data/default_shader__IN_col3_uv2__OUT_col4.spv.frag
if %errorlevel% neq 0 exit /b 1

glslc ./shaders/default_shader__IN_col3_col3__OUT_col3.glsl.vert -o %build_path%/data/default_shader__IN_col3_col3__OUT_col3.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/default_shader__IN_col3__OUT_col3.glsl.frag -o %build_path%/data/default_shader__IN_col3__OUT_col3.spv.frag
if %errorlevel% neq 0 exit /b 1

odin build ./source/ -debug -out:%build_path%\bin\%project_name%.exe
if %errorlevel% neq 0 exit /b 1

if "%~1" == "run" (
    cd build
    cd %build_name%
    cd bin
    %project_name%.exe
)
