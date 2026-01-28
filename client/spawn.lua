AddEventHandler('onClientGameTypeStart', function()
    local defaultSpawn = vector4(-540.58, -212.02, 37.65, 208.88)
    local hospitalSpawn = vector4(354.09, -603.54, 28.78, 260.0)
    local firstSpawn = true

    exports.spawnmanager:setAutoSpawnCallback(function()
        if firstSpawn then
            -- Spawn player at default spawnpoint with model
            exports.spawnmanager:spawnPlayer({
                x = defaultSpawn.x,
                y = defaultSpawn.y,
                z = defaultSpawn.z,
                heading = defaultSpawn.w,
                model = 'a_m_m_skater_01',
                skipFade = false
            })
            firstSpawn = false
        else
            -- Spawn player at hospital spawnpoint
            exports.spawnmanager:spawnPlayer({
                x = hospitalSpawn.x,
                y = hospitalSpawn.y,
                z = hospitalSpawn.z,
                heading = hospitalSpawn.w,
                -- model = 'a_m_m_skater_01', -- Optional: Not specifying will preserve ped model player was using beforehand
                skipFade = false
            }, function()
                ClearPedBloodDamage(PlayerPedId())
            end)
        end
    end)

    exports.spawnmanager:setAutoSpawn(true)
    --exports.spawnmanager:forceRespawn() -- Skips 2-second delay before auto-spawning
end)
