package logging
import win "core:sys/windows"
import "core:log"
import "core:fmt"
import "base:runtime"
import "core:strings"
import "core:os"
import "core:path/filepath"

foreign import kernel32 "system:kernel32.lib"
@(default_calling_convention = "stdcall")
foreign kernel32
{
    AddVectoredExceptionHandler :: proc(
        first: win.ULONG,
        handler: rawptr
    ) -> rawptr ---
}


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
    
    handler_ptr := AddVectoredExceptionHandler(1, cast(rawptr) vectored_exception_handler)
    if handler_ptr==nil do log.error("AddVectoredExceptionHandler returned a nil")

    return logging_context
}

vectored_exception_handler :: proc "stdcall" (ex: ^win.EXCEPTION_POINTERS) -> win.LONG
{
    context = logging_context// so logging_context's logger can forward this
    ex_rec := ex.ExceptionRecord;

    ex_codename: string
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
        case STATUS_ACCESS_VIOLATION: ex_codename = "ACCESS_VIOLATION"
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
    }
    log.errorf("Exception thrown at {} in ______: %x: {} location _____", ex_rec.ExceptionAddress, ex_rec.ExceptionCode, ex_codename)
    return 0
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

STATUS_WAIT_0 :: 0x00000000
STATUS_ABANDONED_WAIT_0 :: 0x00000080
STATUS_USER_APC :: 0x000000C0
STATUS_TIMEOUT :: 0x00000102
STATUS_PENDING :: 0x00000103
DBG_EXCEPTION_HANDLED :: 0x00010001
DBG_CONTINUE :: 0x00010002
STATUS_SEGMENT_NOTIFICATION :: 0x40000005
STATUS_FATAL_APP_EXIT :: 0x40000015
DBG_REPLY_LATER :: 0x40010001
DBG_TERMINATE_THREAD :: 0x40010003
DBG_TERMINATE_PROCESS :: 0x40010004
DBG_CONTROL_C :: 0x40010005
DBG_PRINTEXCEPTION_C :: 0x40010006
DBG_RIPEXCEPTION :: 0x40010007
DBG_CONTROL_BREAK :: 0x40010008
DBG_COMMAND_EXCEPTION :: 0x40010009
DBG_PRINTEXCEPTION_WIDE_C :: 0x4001000A
STATUS_GUARD_PAGE_VIOLATION :: 0x80000001
STATUS_DATATYPE_MISALIGNMENT :: 0x80000002
STATUS_BREAKPOINT :: 0x80000003
STATUS_SINGLE_STEP :: 0x80000004
STATUS_LONGJUMP :: 0x80000026
STATUS_UNWIND_CONSOLIDATE :: 0x80000029
DBG_EXCEPTION_NOT_HANDLED :: 0x80010001
STATUS_ACCESS_VIOLATION :: 0xC0000005
STATUS_IN_PAGE_ERROR :: 0xC0000006
STATUS_INVALID_HANDLE :: 0xC0000008
STATUS_INVALID_PARAMETER :: 0xC000000D
STATUS_NO_MEMORY :: 0xC0000017
STATUS_ILLEGAL_INSTRUCTION :: 0xC000001D
STATUS_NONCONTINUABLE_EXCEPTION :: 0xC0000025
STATUS_INVALID_DISPOSITION :: 0xC0000026
STATUS_ARRAY_BOUNDS_EXCEEDED :: 0xC000008C
STATUS_FLOAT_DENORMAL_OPERAND :: 0xC000008D
STATUS_FLOAT_DIVIDE_BY_ZERO :: 0xC000008E
STATUS_FLOAT_INEXACT_RESULT :: 0xC000008F
STATUS_FLOAT_INVALID_OPERATION :: 0xC0000090
STATUS_FLOAT_OVERFLOW :: 0xC0000091
STATUS_FLOAT_STACK_CHECK :: 0xC0000092
STATUS_FLOAT_UNDERFLOW :: 0xC0000093
STATUS_INTEGER_DIVIDE_BY_ZERO :: 0xC0000094
STATUS_INTEGER_OVERFLOW :: 0xC0000095
STATUS_PRIVILEGED_INSTRUCTION :: 0xC0000096
STATUS_STACK_OVERFLOW :: 0xC00000FD
STATUS_DLL_NOT_FOUND :: 0xC0000135
STATUS_ORDINAL_NOT_FOUND :: 0xC0000138
STATUS_ENTRYPOINT_NOT_FOUND :: 0xC0000139
STATUS_CONTROL_C_EXIT :: 0xC000013A
STATUS_DLL_INIT_FAILED :: 0xC0000142
STATUS_FLOAT_MULTIPLE_FAULTS :: 0xC00002B4
STATUS_FLOAT_MULTIPLE_TRAPS :: 0xC00002B5
STATUS_REG_NAT_CONSUMPTION :: 0xC00002C9
STATUS_HEAP_CORRUPTION :: 0xC0000374
STATUS_STACK_BUFFER_OVERRUN :: 0xC0000409
STATUS_INVALID_CRUNTIME_PARAMETER :: 0xC0000417
STATUS_ASSERTION_FAILURE :: 0xC0000420
STATUS_ENCLAVE_VIOLATION :: 0xC00004A2
STATUS_SXS_EARLY_DEACTIVATION :: 0xC015000F
STATUS_SXS_INVALID_DEACTIVATION :: 0xC0150010
