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

copy_file :: proc(src_path: string, dst_path: string) -> bool {
    src_handle: os.Handle
    if handle, err := os.open(src_path); err==nil {
        src_handle = handle
    } else {
        log.errorf("Error opening src file: \"%s\", %v", src_path, err)
        return false
    }
    defer os.close(src_handle)

    dst_handle: os.Handle
    if handle, err := os.open(dst_path, os.O_CREATE | os.O_TRUNC | os.O_WRONLY); err==nil {
        dst_handle = handle
    } else {
        log.errorf("Error creating dst file: %s, %v", dst_path, err)
        return false
    }
    defer os.close(dst_handle)

    buffer := make([]byte, 1024*1024*50)
    defer delete(buffer)
    for {
        n, read_err := os.read(src_handle, buffer[:])
        
        if read_err != nil && read_err != os.ERROR_EOF {
            log.errorf("Error reading src file: %s, %v", src_path, read_err)
            return false
        }

        if n==0 || read_err==os.ERROR_EOF {
            break
        }

        _, err_zapisu := os.write(dst_handle, buffer[:n])
        if err_zapisu != nil {
            log.errorf("Error writing dst file: %s, %v", dst_path, err_zapisu)
            return false
        }
    }

    log.debugf("File copied successfully, src: \"%s\", dst: \"%s\"", src_path, dst_path)
    return true
}


remove_dir_and_content :: proc(path: string) -> bool {
    for element in get_dir_content(path, context.temp_allocator) {
        full_path := filepath.join([]string{path, element.name})
        if element.is_dir {
            remove_dir_and_content(full_path)
        } else {
            if err := os.remove(full_path); err!=nil {
                log.errorf("Error removing file: \"%s\", %v", full_path, err)
                return false
            }
        }
    }

    if err := os.remove(path); err!=nil {
        log.errorf("Error removing directory: \"%s\", %v", path, err)
    }

    return true
}

get_dir_content :: proc(path: string, allocator := context.allocator) -> []os.File_Info {
    if info, err := os.stat(path); err==nil {
        dir_handle: os.Handle
        if handle, err := os.open(path); err==nil {
            dir_handle = handle
        } else {
            log.errorf("Error opening directory: %v", err)
            return nil
        }
        defer os.close(dir_handle)

        file_info_array: []os.File_Info
        if arr, err := os.read_dir(dir_handle, 0, allocator); err==nil {
            file_info_array = arr
        } else {
            log.errorf("Error reading dir content: %v", err)
            return nil
        }

        return file_info_array
    } else {
        log.errorf("Error checking path: %v", err)
        return nil
    }
}
