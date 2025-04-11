package game
import "core:math"
import "core:log"
import "core:math/linalg"
import "../app"
import "../input"


init :: proc ()
{
    // create main camera entity
    main_camera = create_entity_and_components(
        Transform_Component{
            value = matrix[4,4]f32{
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1,
            }
        },
        Camera_Component{},
    )
}

close :: proc ()
{

}

tick :: proc ()
{
    // update rotation component entities:
    {
        rotate: Rotation_Component
        rotate_index := -1
        transform: Transform_Component
        transform_index := -1
        for entity in entities {
            if comps, exist := components[entity]; exist {
                comp_index := 0
                for comp in comps {
                    if tc, is := comp.(Transform_Component); is {
                        transform = tc
                        transform_index = comp_index
                        continue
                    }
                    else if rc, is := comp.(Rotation_Component); is {
                        rotate = rc
                        rotate_index = comp_index
                        continue
                    }
                }
                if rotate_index!=-1 && transform_index!=-1 {
                    comps[transform_index] = Transform_Component{
                        value = transform.value * linalg.matrix4_rotate_f32(f32(linalg.TAU) * f32(app.time_delta) * rotate.speed, rotate.axis)
                    }
                    rotate_index = -1
                    transform_index = -1
                }
                comp_index += 1
            }
        }
    }

    // handle camera movement:
    if comps, exist := components[main_camera]; exist {
        comp_index := 0
        for comp in comps {
            if transform, is := comp.(Transform_Component); is {
                dt := f32(app.time_delta)
                comps[comp_index] = Transform_Component{
                    value = transform.value * linalg.matrix4_translate_f32([3]f32{-input.move[0]*10*dt, 0, input.move[1]*10*dt})
                }
            }
        }
        comp_index += 1
    }
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
