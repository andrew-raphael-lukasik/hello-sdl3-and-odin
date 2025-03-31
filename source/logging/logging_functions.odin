package logging
import win "core:sys/windows"
import "core:log"
import "core:fmt"
import "base:runtime"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:time"

foreign import kernel32 "system:kernel32.lib"
@(default_calling_convention = "stdcall")
foreign kernel32
{
    AddVectoredExceptionHandler :: proc(
        first: win.ULONG,
        handler: rawptr
    ) -> rawptr ---
}


init :: proc(lowest: log.Level = log.Level.Debug) -> runtime.Context
{
    logging_context = context
    
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
    
    handler_ptr := AddVectoredExceptionHandler(1, cast(rawptr) vectored_exception_handler)
    if handler_ptr==nil do log.error("AddVectoredExceptionHandler returned a nil")

    return logging_context
}

vectored_exception_handler :: proc "stdcall" (ex: ^win.EXCEPTION_POINTERS) -> win.LONG
{
    context = logging_context// so logging_context's logger can forward this

    t := time.now()
    h, m, s := time.clock_from_time(t)
    date, _ := time.time_to_datetime(t)

    ex_codename: string = "<unrecognized>"
    ex_rec := ex.ExceptionRecord;
    switch ex_rec.ExceptionCode
    {
        case STATUS_WAIT_0: ex_codename = "WAIT_0"
        case STATUS_ABANDONED_WAIT_0: ex_codename = "ABANDONED_WAIT_0"
        case STATUS_USER_APC: ex_codename = "USER_APC"
        case STATUS_TIMEOUT: ex_codename = "TIMEOUT"
        case STATUS_PENDING: ex_codename = "PENDING"
        case DBG_EXCEPTION_HANDLED: ex_codename = "EXCEPTION_HANDLED"
        case DBG_CONTINUE: ex_codename = "CONTINUE"
        case STATUS_SEGMENT_NOTIFICATION: ex_codename = "SEGMENT_NOTIFICATION"
        case STATUS_FATAL_APP_EXIT: ex_codename = "FATAL_APP_EXIT"
        case DBG_REPLY_LATER: ex_codename = "REPLY_LATER"
        case DBG_TERMINATE_THREAD: ex_codename = "TERMINATE_THREAD"
        case DBG_TERMINATE_PROCESS: ex_codename = "TERMINATE_PROCESS"
        case DBG_CONTROL_C: ex_codename = "CONTROL_C"
        case DBG_PRINTEXCEPTION_C: ex_codename = "PRINTEXCEPTION_C"
        case DBG_RIPEXCEPTION: ex_codename = "RIPEXCEPTION"
        case DBG_CONTROL_BREAK: ex_codename = "CONTROL_BREAK"
        case DBG_COMMAND_EXCEPTION: ex_codename = "COMMAND_EXCEPTION"
        case DBG_PRINTEXCEPTION_WIDE_C: ex_codename = "PRINTEXCEPTION_WIDE_C"
        case STATUS_GUARD_PAGE_VIOLATION: ex_codename = "GUARD_PAGE_VIOLATION"
        case STATUS_DATATYPE_MISALIGNMENT: ex_codename = "DATATYPE_MISALIGNMENT"
        case STATUS_BREAKPOINT: ex_codename = "BREAKPOINT"
        case STATUS_SINGLE_STEP: ex_codename = "SINGLE_STEP"
        case STATUS_LONGJUMP: ex_codename = "LONGJUMP"
        case STATUS_UNWIND_CONSOLIDATE: ex_codename = "UNWIND_CONSOLIDATE"
        case DBG_EXCEPTION_NOT_HANDLED: ex_codename = "EXCEPTION_NOT_HANDLED"
        case STATUS_ACCESS_VIOLATION:
        {
            ex_codename = "ACCESS_VIOLATION"
            access_type_code := cast(uintptr) ex.ExceptionRecord.ExceptionInformation[0]
            if access_type_code==0 do ex_codename = "ACCESS_VIOLATION Reading"
            else if access_type_code==1 do ex_codename = "ACCESS_VIOLATION Writing"
        }
        case STATUS_IN_PAGE_ERROR: ex_codename = "IN_PAGE_ERROR"
        case STATUS_INVALID_HANDLE: ex_codename = "INVALID_HANDLE"
        case STATUS_INVALID_PARAMETER: ex_codename = "INVALID_PARAMETER"
        case STATUS_NO_MEMORY: ex_codename = "NO_MEMORY"
        case STATUS_ILLEGAL_INSTRUCTION: ex_codename = "ILLEGAL_INSTRUCTION"
        case STATUS_NONCONTINUABLE_EXCEPTION: ex_codename = "NONCONTINUABLE_EXCEPTION"
        case STATUS_INVALID_DISPOSITION: ex_codename = "INVALID_DISPOSITION"
        case STATUS_ARRAY_BOUNDS_EXCEEDED: ex_codename = "ARRAY_BOUNDS_EXCEEDED"
        case STATUS_FLOAT_DENORMAL_OPERAND: ex_codename = "FLOAT_DENORMAL_OPERAND"
        case STATUS_FLOAT_DIVIDE_BY_ZERO: ex_codename = "FLOAT_DIVIDE_BY_ZERO"
        case STATUS_FLOAT_INEXACT_RESULT: ex_codename = "FLOAT_INEXACT_RESULT"
        case STATUS_FLOAT_INVALID_OPERATION: ex_codename = "FLOAT_INVALID_OPERATION"
        case STATUS_FLOAT_OVERFLOW: ex_codename = "FLOAT_OVERFLOW"
        case STATUS_FLOAT_STACK_CHECK: ex_codename = "FLOAT_STACK_CHECK"
        case STATUS_FLOAT_UNDERFLOW: ex_codename = "FLOAT_UNDERFLOW"
        case STATUS_INTEGER_DIVIDE_BY_ZERO: ex_codename = "INTEGER_DIVIDE_BY_ZERO"
        case STATUS_INTEGER_OVERFLOW: ex_codename = "INTEGER_OVERFLOW"
        case STATUS_PRIVILEGED_INSTRUCTION: ex_codename = "PRIVILEGED_INSTRUCTION"
        case STATUS_STACK_OVERFLOW: ex_codename = "STACK_OVERFLOW"
        case STATUS_DLL_NOT_FOUND: ex_codename = "DLL_NOT_FOUND"
        case STATUS_ORDINAL_NOT_FOUND: ex_codename = "ORDINAL_NOT_FOUND"
        case STATUS_ENTRYPOINT_NOT_FOUND: ex_codename = "ENTRYPOINT_NOT_FOUND"
        case STATUS_CONTROL_C_EXIT: ex_codename = "CONTROL_C_EXIT"
        case STATUS_DLL_INIT_FAILED: ex_codename = "DLL_INIT_FAILED"
        case STATUS_FLOAT_MULTIPLE_FAULTS: ex_codename = "FLOAT_MULTIPLE_FAULTS"
        case STATUS_FLOAT_MULTIPLE_TRAPS: ex_codename = "FLOAT_MULTIPLE_TRAPS"
        case STATUS_REG_NAT_CONSUMPTION: ex_codename = "REG_NAT_CONSUMPTION"
        case STATUS_HEAP_CORRUPTION: ex_codename = "HEAP_CORRUPTION"
        case STATUS_STACK_BUFFER_OVERRUN: ex_codename = "STACK_BUFFER_OVERRUN"
        case STATUS_INVALID_CRUNTIME_PARAMETER: ex_codename = "INVALID_CRUNTIME_PARAMETER"
        case STATUS_ASSERTION_FAILURE: ex_codename = "ASSERTION_FAILURE"
        case STATUS_ENCLAVE_VIOLATION: ex_codename = "ENCLAVE_VIOLATION"
        case STATUS_SXS_EARLY_DEACTIVATION: ex_codename = "SXS_EARLY_DEACTIVATION"
        case STATUS_SXS_INVALID_DEACTIVATION: ex_codename = "SXS_INVALID_DEACTIVATION"
        case MS_VC_EXCEPTION:
        {
            // ex_codename = "MS_VC_EXCEPTION"
            // This is a Visual Studio-related non-exception that sets a thread name by throwing an exception
            // Readme: https://learn.microsoft.com/en-us/visualstudio/debugger/tips-for-debugging-threads?view=vs-2022&tabs=csharp#set-a-thread-name-by-throwing-an-exception
            return EXCEPTION_CONTINUE_EXECUTION
        }
    }

    exception_address := ex_rec.ExceptionAddress
    module_name := get_module_name()
    exception_code := ex_rec.ExceptionCode
    access_address := ex_rec.ExceptionInformation[1]
    fmt.printfln("{}[EXCEPTION]{} --- [%04d-%02d-%02d %02d:%02d:%02d] Exception thrown at {} in %s: %x: {}{}{} location {}", ANSI_MAGENTA, ANSI_RESET, date.year, date.month, date.day, h, m, s, exception_address, module_name, exception_code, ANSI_BOLD, ex_codename, ANSI_RESET, access_address)
    
    EXCEPTION_CONTINUE_EXECUTION :: -1// continues program execution
    EXCEPTION_CONTINUE_SEARCH :: 0// breaks program execution
    return EXCEPTION_CONTINUE_SEARCH
}

// readme: https://pkg.odin-lang.org/core/debug/trace/
on_assertion_failure :: proc(prefix, message: string, loc := #caller_location) -> !
{
    log.errorf("Asserion '{}' failed, loc: {}", message, loc)
    default_assertion_failure_proc(prefix, message,loc)
    // runtime.trap()
}

get_module_name :: proc() -> string
{
    h_module := win.GetModuleHandleW(nil)
    if h_module!=nil {
        module_name_buf := make([]u16, 256)
        if win.GetModuleFileNameW(h_module, &module_name_buf[0], u32(len(module_name_buf)))!=0
        {
            utf8_str := win.WideCharToMultiByte(win.CP_UTF8, 0, &module_name_buf[0], -1, nil, 0, nil, nil)
            buf := make([]byte, utf8_str, context.temp_allocator)
            win.WideCharToMultiByte(win.CP_UTF8, 0, &module_name_buf[0], -1, &buf[0], utf8_str, nil, nil)
            return string(buf[:utf8_str-1])
        }
    }
    return "<unknown>"
}
