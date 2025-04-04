set project_name=hello-sdl3
set build_name=win64-debug
set build_path=%~dp0build\%build_name%

@REM TODO: at some point figure out a better way of preparing data files
if exist "%build_path%" (
    echo Build directory exists, clearing it's content before build starts...
    del /q /s "%build_path%\*.*"
    for /f "delims=" %%d in ('dir /s /b /ad "%build_path%\*"') do (
        rd /s /q "%%d"
    )
)
md %build_path%\data 2> nul
glslc ./shaders/default_shader.glsl.vert -o %build_path%/data/default_shader.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/default_shader.glsl.frag -o %build_path%/data/default_shader.spv.frag
if %errorlevel% neq 0 exit /b 1
copy "%~dp0assets\default_cube.gltf" %build_path%\data\
copy "%~dp0assets\texture-00.png" %build_path%\data\

odin build ./source/ -debug
if %errorlevel% neq 0 exit /b 1
md %build_path%\bin 2> nul
move source.exe %build_path%\bin\%project_name%.exe
move source.pdb %build_path%\bin\%project_name%.pdb
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
