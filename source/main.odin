package main
import "core:log"
import "render"
import "input"
import "app"
import "game"
import "logging"


main :: proc ()
{
    when ODIN_DEBUG
    {
        context = logging.init(log_file_name="program.log")
    }

    context = app.init()
    game.init()
    input.init()
    render.init()

    for app.alive!=0
    {
        app.tick()
        input.tick()
        game.tick()
        render.tick()
    }

    game.close()
    input.close()
    render.close()
    app.close()
    when ODIN_DEBUG
    {
        log.debug("Application closed")
        logging.close()
    }
}
