package game
import "core:math"
import "core:log"
import "core:math/linalg"
import sdl "vendor:sdl3"
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
                0, 0, 1, 10,
                0, 0, 0, 1,
            }
        },
        Camera_Component{},
    )
}

close :: proc ()
{
    delete_map(entities)
    
    for entity, components in components {
        delete_dynamic_array(components)
    }
    delete_map(components)
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

    // handle camera movement & rotation:
    if comps, exist := components[main_camera]; exist {
        comp_index := 0
        for comp in comps {
            if transform, is := comp.(Transform_Component); is {
                dt := f32(app.time_delta)
                xxx := transform.value[0].xyz
                yyy := transform.value[1].xyz
                zzz := transform.value[2].xyz
                www := transform.value[3].xyz
                
                // mouse look
                if input.action_mouse_move!={0, 0} {
                    rot := linalg.quaternion_angle_axis_f32(input.action_mouse_move.x * camera_look_sensitivity.x, {0, -1, 0})
                    dot_zzz_010 := linalg.dot(zzz, [3]f32{0, 1, 0})
                    if (input.action_mouse_move.y<0 && dot_zzz_010>-0.9) || (input.action_mouse_move.y>0 && dot_zzz_010<0.9) {
                        rot *= linalg.quaternion_angle_axis_f32(input.action_mouse_move.y * camera_look_sensitivity.y, -xxx)
                    }
                    xxx = linalg.quaternion_mul_vector3(rot, linalg.normalize(xxx))
                    yyy = linalg.quaternion_mul_vector3(rot, linalg.normalize(yyy))
                    zzz = linalg.cross(xxx, yyy)
                }
                
                // move
                www += (xxx * input.action_move.x + -zzz * input.action_move.y + yyy * (input.action_jump - input.action_crouch)) * dt * 10
                
                // write back
                comps[comp_index] = Transform_Component{
                    value = {
                        xxx[0], yyy[0], zzz[0], www.x,
                        xxx[1], yyy[1], zzz[1], www.y,
                        xxx[2], yyy[2], zzz[2], www.z,
                        0, 0, 0, 1,
                    }
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
    entities[entity] = true
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
        entities[entity] = false
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
    return entities[entity]==true
}
