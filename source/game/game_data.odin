package game


entities := make_map(map[Entity]byte)
entities_index: u32 = 0
components := make_map(map[Entity][dynamic]Component)
