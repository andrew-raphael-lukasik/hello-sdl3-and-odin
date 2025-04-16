package build


path_bin := "build/win64-debug/bin"
path_data := "build/win64-debug/data"
directories_to_delete := []string{
    "build"
}
paths_to_create := []string{
    path_bin,
    path_data
}
data_file_types_to_copy := []string{
    ".gltf",
    ".png"
}
bin_files_to_copy := []string{
    "source/render/redistributable_bin/SDL3.dll",
    "source/render/redistributable_bin/SDL3_image.dll",
    "source/steam/steamworks/redistributable_bin/win64/steam_api64.dll",
    "source/steam/steam_appid.txt",
}
