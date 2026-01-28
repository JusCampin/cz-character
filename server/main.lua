local function start_version_check(core)
	if not core or not core.Versioner or not core.Versioner.checkFile then return false end
	core.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/JusCampin/cz-character')
	return true
end

local ok, core = pcall(function() return exports['cz-core']:GetCore() end)
if ok and core then
	if core.waitForReady and type(core.waitForReady) == 'function' then
		core.waitForReady(function(c) start_version_check(c) end)
	else
		start_version_check(core)
	end
else
	-- fallback to event if GetCore isn't available at all
	AddEventHandler('cz-core:ready', function()
		local ok2, core2 = pcall(function() return exports['cz-core']:GetCore() end)
		if not ok2 or not core2 then
			print('[cz-character] failed to obtain Core API after cz-core ready event')
			return
		end
		start_version_check(core2)
	end)
end
