-- cz-character server startup (event-only)

local function start_version_check(core)
	if not core or not core.Versioner or not core.Versioner.checkFile then
		return
	end
	core.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/JusCampin/cz-character')
end

-- Event-only handshake: register ready handler and request the API
-- prefer the `CZCore` global if available; otherwise use the event/request handshake
-- lightweight logger that prefers CZLog when available
local Log = {}
function Log.info(msg) if CZLog and CZLog.info then CZLog.info(msg) else print(tostring(msg)) end end
function Log.warn(msg) if CZLog and CZLog.warn then CZLog.warn(msg) else print(tostring(msg)) end end
function Log.error(msg) if CZLog and CZLog.error then CZLog.error(msg) else print(tostring(msg)) end end

if type(CZCore) == 'table' then
	Log.info('Using CZCore global for cz-character startup')
	start_version_check(CZCore)
else
	AddEventHandler('cz-core:ready', function(core)
		if type(core) == 'table' then
			start_version_check(core)
		end
	end)
	-- Immediately request the core API in case it was missed
	TriggerEvent('cz-core:request_api')
end
