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
        Camera_Component{},
    )
    transforms[main_camera] = Transform{
        matrix3x3 = linalg.MATRIX3F32_IDENTITY,
        translation = {0, 0, 10},
    }
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
    for entity in entities {
        if comps, exist := components[entity]; exist {
            for comp in comps {
                if rc, is := comp.(Rotation_Component); is {
                    transforms[entity] = Transform{
                        matrix3x3 = linalg.matrix3_rotate_f32(f32(linalg.TAU) * (f32(app.time_tick) + rc.offset) * rc.speed, rc.axis),
                        translation = transforms[entity].translation,
                    }
                }
            }
        }
    }

    // handle camera movement & rotation:
    if comps, exist := components[main_camera]; exist {
        dt := f32(app.time_delta)
        transform := transforms[main_camera]
        xxx := transform.matrix3x3[0]
        yyy := transform.matrix3x3[1]
        zzz := transform.matrix3x3[2]
        pos := transform.translation
        
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
        pos += (xxx * input.action_move.x + -zzz * input.action_move.y + yyy * (input.action_jump - input.action_crouch)) * dt * 10
        
        // write back
        transforms[main_camera] = Transform{
            matrix3x3 = matrix[3,3]f32{
                xxx[0], yyy[0], zzz[0],
                xxx[1], yyy[1], zzz[1],
                xxx[2], yyy[2], zzz[2],
            },
            translation = pos,
        }
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
