package input
import sdl "vendor:sdl3"


key_down: map[sdl.Scancode]bool
key_up: map[sdl.Scancode]bool
mouse_down: map[u8]bool
mouse_up: map[u8]bool

action_move: [2]f32
action_mouse_move: [2]f32
action_jump: f32
action_crouch: f32
