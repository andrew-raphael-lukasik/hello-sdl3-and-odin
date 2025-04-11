package game
import "core:math"
import "core:fmt"


init :: proc ()
{
    
}

close :: proc ()
{

}

tick :: proc ()
{
    
}


create_entity :: proc () -> Entity
{
    entity := Entity{
        index = entities_index,
        version = 1,
    }
    entities_index += 1
    append(&entities, entity)
    return entity
}

create_entity_and_components :: proc ( args: ..Component) -> Entity
{
    entity := create_entity()
    if values, exists := &components[entity]; !exists {
        components[entity] = make_dynamic_array([dynamic]Component)
    }
    for comp in args {
        append(&components[entity], comp)
    }
    return entity
}

destroy_entity :: proc (entity: Entity) -> bool
{
    for i:=0 ; i<len(entities) ; i+=1 {
        if entities[i]==entity {
            unordered_remove(&entities, i)
            return true
        }
    }
    return false
}
