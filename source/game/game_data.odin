package game


entities := make_map(map[Entity]bool)
entities_index: u32 = 0
components := make_map(map[Entity][dynamic]Component)
main_camera: Entity
camera_look_sensitivity: [2]f32 = {0.01, 0.01}
