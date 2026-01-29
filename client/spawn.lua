CZCharacterSpawnPoints = CZCharacterSpawnPoints or {}

AddEventHandler('onClientGameTypeStart', function()
    local spawnPoints = CZCharacterSpawnPoints or nil
    local function pickSpawn()
        if type(spawnPoints) == 'table' and #spawnPoints > 0 then
            local idx = math.random(#spawnPoints)
            local s = spawnPoints[idx]
            return vector4(s.x or 0, s.y or 0, s.z or 0, s.heading or 0)
        end
        return vector4(-540.58, -212.02, 37.65, 208.88)
    end
    local defaultSpawn = pickSpawn()
    local hospitalSpawn = pickSpawn()
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
