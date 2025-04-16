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

    for element in get_dir_content("assets", context.temp_allocator) {
        if !element.is_dir {
            for ext in data_file_types_to_copy {
                if strings.ends_with(element.name, ext) {
                    copy_file(element.fullpath, filepath.join([]string{path_data, element.name}, context.temp_allocator))
                }
            }
        }
    }

    for path in bin_files_to_copy {
        copy_file(path, filepath.join([]string{path_bin, filepath.base(path)}, context.temp_allocator))
    }

    logging.close()
}
