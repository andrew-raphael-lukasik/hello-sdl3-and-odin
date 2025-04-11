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
    entities[entity] = 1
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
    if exists_entity(entity) {
        entities[entity] = 0
        if components[entity]!=nil{
            delete_dynamic_array(components[entity])
            components[entity] = nil
        }
        return true
    }
    return false
}

exists_entity :: proc (entity: Entity) -> bool
{
    return entities[entity]==1
}
