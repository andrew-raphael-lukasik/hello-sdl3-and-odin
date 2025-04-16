package build
import "core:io"
import "core:os"
import "core:mem"
import "core:log"
import "core:path/filepath"
import "../render/glTF2"
import "../logging"
import "../app"


main :: proc ()
{
    context = logging.init(log_file_name="build_preprocessor.log")

    // log.debug("Build directory exists, clearing it's content before build starts...")
    if remove_dir_and_content("build") {
        log.debug("build dir removed successfully")
    }

    if err := os.make_directory("build"); err!=nil {
        log.errorf("os.make_directory(\"build\") thrown error {}", err)
    } else {
        if err := os.make_directory("build/win64-debug"); err!=nil {
            log.errorf("os.make_directory(\"build/win64-debug\") thrown error {}", err)
        } else {
            if err := os.make_directory("build/win64-debug/bin"); err!=nil {
                log.errorf("os.make_directory(\"build/win64-debug/bin\") thrown error {}", err)
            }
            if err := os.make_directory("build/win64-debug/data"); err!=nil {
                log.errorf("os.make_directory(\"build/win64-debug/data\") thrown error {}", err)
            }
        }
    }

    logging.close()
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
                    log.errorf("Error removing file: %s, %v", full_path, err)
                }
            }
        }

        os.close(dir_handle)
        if err := os.remove(path); err!=nil {
            log.errorf("Error removing directory: %s, %v", path, err)
        }

        return true
    } else {
        log.errorf("Error checking path: %v", err)
        return false
    }
}
