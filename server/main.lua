-- cz-character server startup (event-only)

local function start_version_check(core)
	if not core or not core.Versioner or not core.Versioner.checkFile then
		return
	end
	core.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/JusCampin/cz-character')
end

-- Event-only handshake: register ready handler and request the API
AddEventHandler('cz-core:ready', function(core)
	if type(core) == 'table' then
		start_version_check(core)
	else
		-- missing core arg — ignore
	end
end)

-- Immediately request the core API in case it was missed
TriggerEvent('cz-core:request_api')
