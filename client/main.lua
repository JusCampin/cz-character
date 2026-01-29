-- cz-character client main
local reported = false
local hasSelectedCharacter = false
local charMenuShown = false
local expecting_select = false
local skip_reopen_until = 0
local suppress_open_until = 0
local DEBUG_CZCHAR = false
local CZCoreDevMode = false
-- read local resource dev flag from our config (keeps debug local to this resource)
local okDev, devVal = pcall(function() return (Config and Config.Dev and Config.Dev.enabled) or false end)
CZCoreDevMode = (okDev and devVal) and true or false
DEBUG_CZCHAR = CZCoreDevMode

AddEventHandler('playerSpawned', function(spawn)
    -- if player hasn't selected a character this session, open the char menu
    Citizen.SetTimeout(100, function()
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            if not hasSelectedCharacter and not expecting_select and GetGameTimer() > (skip_reopen_until or 0) and GetGameTimer() > (suppress_open_until or 0) then
                if DEBUG_CZCHAR then print('[cz-character] playerSpawned requesting characters') end
                TriggerServerEvent('cz-character:request_characters')
                charMenuShown = true
            end
            -- still report an initial location for safety
            if not reported then
                local coords = GetEntityCoords(ped)
                if coords then
                    TriggerServerEvent('cz-character:report_location', coords.x, coords.y, coords.z)
                    reported = true
                end
            end
        end
    end)
end)

-- Simple keyboard input helper (blocking)
local function KeyboardInput(textEntry, exampleText, maxLength)
    AddTextEntry('FMMC_KEY_TIP1', textEntry)
    DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', exampleText or '', '', '', '', maxLength or 64)
    while UpdateOnscreenKeyboard() == 0 do
        Citizen.Wait(0)
    end
    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end
    return nil
end

RegisterCommand('createchar', function()
    local first = KeyboardInput('Enter first name', '', 32)
    if not first or first == '' then
        TriggerEvent('chat:addMessage', { args = { '^1Character creation cancelled' } })
        return
    end
    local last = KeyboardInput('Enter last name (optional)', '', 32)
    last = last or ''
    if CZ_RPC and CZ_RPC.call then
        local ok, res = CZ_RPC.call('cz-character:create_character', nil, first, last)
        if ok and res and res.ok and res.res then
            TriggerEvent('chat:addMessage', { args = { '^2Character created (id: ' .. tostring(res.res) .. ')' } })
        else
            TriggerEvent('chat:addMessage', { args = { '^1Character creation failed: ' .. tostring((res and res.err) or 'unknown') } })
        end
    else
        TriggerServerEvent('cz-character:create_character', first, last)
    end
end, false)

RegisterNetEvent('cz-character:create_character:result')
AddEventHandler('cz-character:create_character:result', function(ok, data)
    if ok then
        TriggerEvent('chat:addMessage', { args = { '^2Character created (id: ' .. tostring(data) .. ')' } })
    else
        TriggerEvent('chat:addMessage', { args = { '^1Character creation failed: ' .. tostring(data) } })
    end
end)

-- NUI: open character menu
RegisterNetEvent('cz-character:response_characters')
AddEventHandler('cz-character:response_characters', function(chars)
    if not chars then chars = {} end
    -- always update the list, but only open the UI if not suppressed
    SendNUIMessage({ action = 'setCharacters', characters = chars, resource = GetCurrentResourceName(), dev = CZCoreDevMode })
    -- if the menu is already shown, just update the list and skip opening
    if charMenuShown then
        if DEBUG_CZCHAR then print('[cz-character] response_characters: menu already shown, updated list only') end
        return
    end
    if GetGameTimer() > (suppress_open_until or 0) then
        SendNUIMessage({ action = 'open', resource = GetCurrentResourceName(), dev = CZCoreDevMode })
        SetNuiFocus(true, true)
        charMenuShown = true
    end
end)

-- dev-mode is local to this resource (see `configs/config.lua`)

RegisterNUICallback('close', function(data, cb)
    if DEBUG_CZCHAR then print('[cz-character] NUI callback `close` received:', data and json.encode(data) or '{}') end
    -- prevent closing the menu before a character is selected
    if not hasSelectedCharacter then
        if DEBUG_CZCHAR then print('[cz-character] close ignored, character not selected') end
        -- keep focus so player remains frozen and menu visible
        cb('denied')
        return
    end
    SetNuiFocus(false, false)
    charMenuShown = false
    cb('ok')
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local id = tonumber(data.id)
    if not id then cb('invalid') return end
    if DEBUG_CZCHAR then print('[cz-character] NUI callback `selectCharacter` received id:', id) end
    -- close UI immediately for responsiveness, server will still perform selection
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    charMenuShown = false
    -- mark that we are expecting the server to spawn us shortly
    expecting_select = true
    -- set a short window during which playerSpawned should not re-open the menu
    skip_reopen_until = GetGameTimer() + 10000 -- 10 seconds
    -- suppress any incoming open for a bit longer while we spawn
    suppress_open_until = GetGameTimer() + 15000 -- 15 seconds
    TriggerServerEvent('cz-character:request_select_character', id)
    cb('ok')
end)

RegisterNUICallback('editCharacter', function(data, cb)
    local id = tonumber(data.id)
    local first = tostring(data.first or '')
    local last = tostring(data.last or '')
    if not id then cb('invalid') return end
    if DEBUG_CZCHAR then print('[cz-character] NUI callback `editCharacter` received:', id, first, last) end
    TriggerServerEvent('cz-character:request_edit_character', id, first, last)
    cb('ok')
end)

RegisterNUICallback('requestCharacters', function(data, cb)
    TriggerServerEvent('cz-character:request_characters')
    cb('ok')
end)

RegisterNetEvent('cz-character:select_character:result')
AddEventHandler('cz-character:select_character:result', function(ok, msg)
    if ok then
        TriggerEvent('chat:addMessage', { args = { '^2Character selected' } })
        -- server acknowledged selection; keep expecting_select until spawn_at clears it
        -- but mark selected as true to avoid re-requesting on future spawns
        hasSelectedCharacter = true
        charMenuShown = false
        SetNuiFocus(false, false)
        if DEBUG_CZCHAR then print('[cz-character] select_character:result ok, awaiting spawn_at') end
    else
        TriggerEvent('chat:addMessage', { args = { '^1Character select failed: ' .. tostring(msg) } })
    end
end)

RegisterNetEvent('cz-character:edit_character:result')
AddEventHandler('cz-character:edit_character:result', function(ok, msg)
    if ok then
        TriggerEvent('chat:addMessage', { args = { '^2Character updated' } })
        TriggerServerEvent('cz-character:request_characters')
    else
        TriggerEvent('chat:addMessage', { args = { '^1Update failed: ' .. tostring(msg) } })
    end
end)

-- spawn at coordinates sent from server after character selection
RegisterNetEvent('cz-character:spawn_at')
AddEventHandler('cz-character:spawn_at', function(x, y, z)
    CreateThread(function()
        if exports and exports.spawnmanager and exports.spawnmanager.spawnPlayer then
            pcall(function()
                exports.spawnmanager:spawnPlayer({ x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0, heading = 0, skipFade = false })
            end)
        else
            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                SetEntityCoords(ped, tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0, false, false, false, true)
            end
        end
        -- start periodic location reporting while player is active
        Start_location_reporting()
        -- spawn applied; NUI will be closed and focus released below
        hasSelectedCharacter = true
        charMenuShown = false
        expecting_select = false
        -- avoid reopening menu for a short window after spawn
        skip_reopen_until = GetGameTimer() + 10000
        -- suppress any incoming open for a bit longer while we finish spawning
        suppress_open_until = GetGameTimer() + 15000
        -- ensure NUI is closed and focus released
        SendNUIMessage({ action = 'close' })
        SetNuiFocus(false, false)
    end)
end)

-- periodic location reporting
local reporting = false
local report_interval = (Config and Config.Character and Config.Character.report_interval) or 10 -- seconds

function Start_location_reporting()
    if reporting then return end
    reporting = true
    CreateThread(function()
        while reporting do
            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                if coords then
                    TriggerServerEvent('cz-character:report_location', coords.x, coords.y, coords.z)
                end
            end
            Citizen.Wait((report_interval or 10) * 1000)
        end
    end)
end

function Stop_location_reporting()
    reporting = false
end

-- (freeze/unfreeze helpers removed; NUI focus controls movement during selection)

RegisterCommand('charmenu', function()
    TriggerServerEvent('cz-character:request_characters')
end, false)

