package build
import "core:io"
import "core:log"
import "../render/glTF2"
import "../logging"


main :: proc ()
{
    context = logging.init(log_file_name="build_utilities.log")

    log.debug("działa")

    logging.close()
}
