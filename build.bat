set project_name=hello-sdl3
set build_name=win64-debug

md %~dp0shaders_compiled 2> nul
glslc ./shaders/shader.glsl.vert -o ./shaders_compiled/shader.spv.vert
if %errorlevel% neq 0 exit /b 1
glslc ./shaders/shader.glsl.frag -o ./shaders_compiled/shader.spv.frag
if %errorlevel% neq 0 exit /b 1

odin build ./source/ -debug
if %errorlevel% neq 0 exit /b 1
set build_path=%~dp0build\%build_name%
md %build_path%\bin 2> nul
move source.exe %build_path%\bin\%project_name%.exe
move source.pdb %build_path%\bin\%project_name%.pdb
copy %~dp0source\render\redistributable_bin\SDL3.dll %build_path%\bin\
copy %~dp0source\steam\steamworks\redistributable_bin\win64\steam_api64.dll %build_path%\bin\
copy %~dp0source\steam\steam_appid.txt %build_path%\bin\

if "%~1" == "run" (
    %build_path%\bin\%project_name%.exe
)
