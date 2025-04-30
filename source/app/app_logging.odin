package app
import "core:log"
import "core:strings"
import "core:fmt"


log_print_slice :: proc (slice: []$E, prefix: string, multiple_lines: bool, location := #caller_location) {
    length := len(slice)
    if length!=0 {
        builder: strings.Builder
        strings.builder_init(&builder, context.temp_allocator)
        defer strings.builder_destroy(&builder)
        
        if multiple_lines {
            fmt.sbprintf(&builder, "\n%s: {{\n", prefix)
            for i:=0 ; i<length ; i+=1 do fmt.sbprintf(&builder, "\t{}\n", slice[i])
        }
        else {
            fmt.sbprintf(&builder, "\n%s: {{{}", prefix, slice[0])
            for i:=1 ; i<length ; i+=1 do fmt.sbprintf(&builder, ", {}", slice[i])
        }
        fmt.sbprint(&builder, "}\n")

        text := strings.to_string(builder)
        log.debug(text, location)
    }
}

log_print_map :: proc (table: map[$K]$E, prefix: string, multiple_lines: bool, location := #caller_location) {
    length := len(table)
    if length!=0 {
        builder: strings.Builder
        strings.builder_init(&builder, context.temp_allocator)
        defer strings.builder_destroy(&builder)
        
        if multiple_lines {
            fmt.sbprintf(&builder, "\n%s: {{\n", prefix)
            for k, v in table do fmt.sbprintf(&builder, "\t{}  -  {}\n", k, v)
        }
        else {
            for k, v in table {
                fmt.sbprintf(&builder, "\n%s: {{{}  -  {}", prefix, k, v)
                break
            }
            for k, v in table do fmt.sbprintf(&builder, ", {}  -  {}", k, v)
        }
        fmt.sbprint(&builder, "}\n")

        text := strings.to_string(builder)
        log.debug(text, location)
    }
}
