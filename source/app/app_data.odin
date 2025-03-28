package app
import "core:time"
import "core:mem"


alive : byte
time_tick: f64 = 0;
time_start: time.Time
dir_current: string
dir_parent: string
arena_allocator : mem.Allocator
arena_buffer: []byte

when ODIN_DEBUG
{
    tracking_allocator: mem.Tracking_Allocator
}
