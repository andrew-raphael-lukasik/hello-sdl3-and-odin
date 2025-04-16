package build
import "core:io"
import "core:os"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "../render/glTF2"
import "../logging"
import "../app"

directories_to_delete := []string{
    "build"
}
paths_to_create := []string{
    "build/win64-debug/bin",
    "build/win64-debug/data"
}

main :: proc ()
{
    context = logging.init(log_file_name="build_preprocessor.log")

    for path in directories_to_delete {
        if os.exists(path) {
            log.debugf("\"%s\" dir exists, clearing it's content before build starts...", path)
            if remove_dir_and_content(path) {
                log.debugf("\"%s\" dir removed successfully", path)
            }
        }
    }

    for path in paths_to_create {
        make_path(path)
        log.debugf("\"%s\" path created successfully", path)
    }

    logging.close()
}

make_path :: proc (path: string)
{
    dir: string
    for next in strings.split(path, "/", context.temp_allocator) {
        dir = len(dir)!=0 ? strings.join([]string{dir, next}, "/", context.temp_allocator) : next
        if err := os.make_directory(dir); err!=nil && err!=os.General_Error.Exist {
            log.errorf("os.make_directory(\"%s\") thrown error {}", dir, err)
            return
        }
    }
}

remove_dir_and_content :: proc(path: string) -> bool {
    if info, err := os.stat(path); err==nil {
        dir_handle: os.Handle
        if handle, err := os.open(path); err==nil {
            dir_handle = handle
        } else {
            log.errorf("Error opening directory: %v", err)
            return false
        }

        files: []os.File_Info
        if arr, err := os.read_dir(dir_handle, 0, context.temp_allocator); err==nil {
            files = arr
        } else {
            log.errorf("Error reading dir content: %v", err)
            return false
        }

        for element in files {
            full_path := filepath.join([]string{path, element.name})
            if element.is_dir {
                remove_dir_and_content(full_path)
            } else {
                if err := os.remove(full_path); err!=nil {
                    log.errorf("Error removing file: \"%s\", %v", full_path, err)
                }
            }
        }

        os.close(dir_handle)
        if err := os.remove(path); err!=nil {
            log.errorf("Error removing directory: \"%s\", %v", path, err)
        }

        return true
    } else {
        log.errorf("Error checking path: %v", err)
        return false
    }
}
