package game


entities := make([dynamic]Entity, 0, 32)
entities_index: u32 = 0
components := make_map(map[Entity][dynamic]Component)
