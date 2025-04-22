package input
import sdl "vendor:sdl3"


key_down: map[sdl.Scancode]bool
key_up: map[sdl.Scancode]bool
mouse_down: map[u8]bool
mouse_up: map[u8]bool
move: [2]f32
mouse_move: [2]f32
