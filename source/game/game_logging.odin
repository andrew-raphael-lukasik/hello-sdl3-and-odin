package game
import "core:log"
import "core:strings"
import "core:fmt"


log_print_entity_components :: proc () {
    builder: strings.Builder
    strings.builder_init(&builder, context.temp_allocator)
    defer strings.builder_destroy(&builder)
    
    for e in entities {
       fmt.sbprintf(&builder, "{}\n", e)
        fmt.sbprintf(&builder, "{}\n", e)
        for c in components[e] {
            fmt.sbprintf(&builder, "\t {}\n", c)
        }
    }

    text := strings.to_string(builder)
    log.debug(text)
}
