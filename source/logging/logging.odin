package logging
import "core:log"
import "base:runtime"
import "core:os"
import "core:path/filepath"


init :: proc(cxt: runtime.Context, lowest: log.Level = log.Level.Debug) -> runtime.Context
{
    logging_context = cxt
    
    default_assertion_failure_proc = logging_context.assertion_failure_proc
    logging_context.assertion_failure_proc = on_assertion_failure

    logging_context.logger = log.create_console_logger(lowest)
    {
        dir_current := os.get_current_directory(logging_context.temp_allocator)
        path := filepath.join([]string{dir_current, "log.txt"}, logging_context.temp_allocator)
        log_file_handle, err := os.open(path, os.O_CREATE | os.O_TRUNC | os.O_WRONLY)
        if err==nil
        {
            log.debugf("Log file path: {}", path)
            file_logger := log.create_file_logger(log_file_handle, lowest)
            multi_logger := log.create_multi_logger(logging_context.logger, file_logger)
            logging_context.logger = multi_logger
        }
        else do log.errorf("'{}' error while creating log file at path: {}", err, path)
    }
    log.debugf("Application started")

    return logging_context
}

// readme: https://pkg.odin-lang.org/core/debug/trace/
on_assertion_failure :: proc(prefix, message: string, loc := #caller_location) -> !
{
    log.errorf("Asserion '{}' failed, loc: {}", message, loc)
    default_assertion_failure_proc(prefix, message,loc)
    // runtime.trap()
}


logging_context : runtime.Context
default_assertion_failure_proc: runtime.Assertion_Failure_Proc
