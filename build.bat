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
copy "%~dp0assets\default_cube.gltf" %build_path%\data\
copy "%~dp0assets\texture-00.png" %build_path%\data\

odin build ./source/ -debug -out:%build_path%\bin\%project_name%.exe
if %errorlevel% neq 0 exit /b 1
copy %~dp0source\render\redistributable_bin\SDL3.dll %build_path%\bin\
copy %~dp0source\render\redistributable_bin\SDL3_image.dll %build_path%\bin\
copy %~dp0source\steam\steamworks\redistributable_bin\win64\steam_api64.dll %build_path%\bin\
copy %~dp0source\steam\steam_appid.txt %build_path%\bin\

if "%~1" == "run" (
    cd build
    cd %build_name%
    cd bin
    %project_name%.exe
)
