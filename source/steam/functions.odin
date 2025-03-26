package steam
import sdl "vendor:sdl3"
import steam "steamworks"
import "core:c"
import "base:runtime"
import "core:mem"
import "core:log"

init :: proc ()
{
    if steam.RestartAppIfNecessary(steam.uAppIdInvalid)
    {
        log.debug("Launching app through Steam...")
        return
    }

    err_msg: steam.SteamErrMsg
    if init_result := steam.InitFlat(&err_msg); init_result!=.OK
    {
        initialized = 0

        log.errorf("steam.InitFlat failed, ESteamAPIInitResult: '{}', message: '{}'", init_result, transmute(cstring)&err_msg[0])
    }
    else
    {
        initialized = 1

        steam.Client_SetWarningMessageHook(steam.Client(), steam_debug_text_hook)
        steam.ManualDispatch_Init()

        if !steam.User_BLoggedOn(steam.User())
        {
            log.warn("Steam user not logged in.")
        }
        else
        {
            log.debugf("Steam user `{}` is logged in and {}.", string(steam.Friends_GetPersonaName(steam.Friends())), steam.Friends_GetPersonaState(steam.Friends()))
        }
    }
}

close :: proc ()
{
    if initialized==1
    {
        steam.Shutdown()
        initialized = 0
    }
}

tick :: proc ()
{
    if initialized==1 do run_steam_callbacks()
}


steam_debug_text_hook :: proc "c" (severity: c.int, debugText: cstring)
{
    // if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
    // if you add -debug_steamworksapi to the command-line, a lot of extra informational messages will also be sent
    runtime.print_string(string(debugText))

    if severity>=1 do runtime.debug_trap()
}

run_steam_callbacks :: proc()
{
    steam_pipe := steam.GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    
    callback: steam.CallbackMsg
    for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback)
    {
        // Check for dispatching API call results
        if callback.iCallback==.SteamAPICallCompleted
        {
            log.debugf("SteamAPICallCompleted, message: {}", callback)

            call_completed := transmute(^steam.SteamAPICallCompleted) callback.pubParam
            if temp_call_res, ok := mem.alloc(int(callback.cubParam), allocator = context.temp_allocator); ok==nil
            {
                failed: bool
                if steam.ManualDispatch_GetAPICallResult(steam_pipe, call_completed.hAsyncCall, temp_call_res, callback.cubParam, callback.iCallback, &failed)
                {
                    // Dispatch the call result to the registered handler(s) for the call identified by call_completed->m_hAsyncCall
                    
                    log.debugf("\tManualDispatch_GetAPICallResult: {}", call_completed)

                    if call_completed.iCallback==.NumberOfCurrentPlayers
                    {
                        on_GetNumberOfCurrentPlayers(transmute(^steam.NumberOfCurrentPlayers) temp_call_res, failed)
                    }
                }
            }
        }
        else if callback.iCallback==.GameOverlayActivated
        {
            on_gameOverlayActivated(transmute(^steam.GameOverlayActivated)callback.pubParam)
        } 

        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}

on_gameOverlayActivated :: proc(data: ^steam.GameOverlayActivated)
{
    if data.bActive==0 do log.debug("Steam overlay deactivated")
    else do log.debug("Steam overlay activated")
}

on_GetNumberOfCurrentPlayers :: proc(data: ^steam.NumberOfCurrentPlayers, failed: bool)
{
    if failed
    {
        log.error("NumberOfCurrentPlayers callback failed.")
        return
    }

    log.debugf("Number of players currently playing: {}\n", data.cPlayers)
    number_of_current_players = int(data.cPlayers)
}

get_number_of_current_players :: proc()
{
    log.debug("Number of current players requested.\n")
    hSteamApiCall := steam.UserStats_GetNumberOfCurrentPlayers(steam.UserStats())
}
