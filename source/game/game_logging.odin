package game
import "core:fmt"


log_print_slice :: proc (slice: []$E, prefix: string, multiple_lines: bool) {
    length := len(slice)
    if length!=0 {
        if multiple_lines {
            fmt.printf("\n%s: {{\n", prefix)
            for i:=0 ; i<length ; i+=1 do fmt.printf("\t{}\n", slice[i])
        }
        else {
            fmt.printf("\n%s: {{{}", prefix, slice[0])
            for i:=1 ; i<length ; i+=1 do fmt.printf(", {}", slice[i])
        }
        fmt.print("}\n")
    }
}

log_print_map :: proc (table: map[$K]$E, prefix: string, multiple_lines: bool) {
    length := len(table)
    if length!=0 {
        if multiple_lines {
            fmt.printf("\n%s: {{\n", prefix)
            for k, v in table do fmt.printf("\t{}  -  {}\n", k, v)
        }
        else {
            for k, v in table {
                fmt.printf("\n%s: {{{}  -  {}", prefix, k, v)
                break
            }
            for k, v in table do fmt.printf(", {}  -  {}", k, v)
        }
        fmt.print("}\n")
    }
}

log_print_entity_components :: proc () {
    for e in entities {
        fmt.printf("{}\n", e)
        for c in components[e] {
            fmt.printf("\t {}\n", c)
        }
    }
}
