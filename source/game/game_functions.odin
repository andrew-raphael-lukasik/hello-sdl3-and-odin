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
        version = 0,
    }
    entities_index += 1
    append(&entities, entity)
    return entity
}
