package app
import "core:time"
import "core:mem"
import "core:mem/virtual"
import "base:runtime"


alive : byte

time_start: time.Time
time_tick: f64 = 0;
time_delta: f64 = 0;

dir_current: string
dir_parent: string

arena: virtual.Arena
arena_allocator : mem.Allocator
arena_buffer: []byte

when ODIN_DEBUG
{
    tracking_allocator: mem.Tracking_Allocator
    default_allocator: mem.Allocator
}

app_context : runtime.Context
