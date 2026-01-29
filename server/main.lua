-- cz-character server startup (event-only)

local function start_version_check(core)
	if not core or not core.Versioner or not core.Versioner.checkFile then return end
	core.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/JusCampin/cz-character')
end

local CoreAPI = CZCore
local dev_enabled = (Config and Config.Dev and Config.Dev.enabled) or false
local Log = {
	info = function(msg) if dev_enabled then if CoreAPI and CoreAPI.Log and CoreAPI.Log.info then CoreAPI.Log.info(msg) else print(tostring(msg)) end end end,
	warn = function(msg) if dev_enabled then if CoreAPI and CoreAPI.Log and CoreAPI.Log.warn then CoreAPI.Log.warn(msg) else print(tostring(msg)) end end end,
	error = function(msg) if CoreAPI and CoreAPI.Log and CoreAPI.Log.error then CoreAPI.Log.error(msg) else print(tostring(msg)) end end,
}

local function choose_primary_identifier(ids)
	if type(ids) ~= 'table' then return nil end
	local priority = { 'license:', 'steam:', 'discord:' }
	for _, p in ipairs(priority) do
		for _, v in ipairs(ids) do
			if tostring(v):find(p, 1, true) then return v end
		end
	end
	for _, v in ipairs(ids) do
		if not tostring(v):find('^ip:') then return v end
	end
	return ids[1]
end

local function choose_spawn_point()
	local s = Config and Config.Character and Config.Character.SpawnPoints
	if type(s) == 'table' and #s > 0 then
		local idx = math.random(#s)
		return s[idx]
	end
	return { x = -540.58, y = -212.02, z = 37.65, heading = 208.88 }
end

local sessions_by_source = {}

-- seed RNG for spawn selection
math.randomseed(os.time())

if type(CZCore) == 'table' then
	CoreAPI = CZCore
	Log.info('Using CZCore global for cz-character startup')
	start_version_check(CoreAPI)
else
	AddEventHandler('cz-core:ready', function(core)
		if type(core) == 'table' then
			CoreAPI = core
			start_version_check(core)
		end
	end)
	TriggerEvent('cz-core:request_api')
end

-- handlers
local function db_query(query, params)
	if MySQL and MySQL.query and MySQL.query.await then
		local ok, res = pcall(MySQL.query.await, query, params)
		if not ok then Log.error('DB query error: ' .. tostring(res)); return nil end
		return res
	end
	Log.warn('MySQL.query.await not available; returning nil')
	return nil
end

local function handle_request_characters(src)
	local ids = GetPlayerIdentifiers(src) or {}
	local primary = choose_primary_identifier(ids)
	if not primary then
		TriggerClientEvent('cz-character:response_characters', src, {})
		return
	end
	local rows = db_query('SELECT id, first_name, last_name, created_at, is_active, last_x, last_y, last_z FROM characters WHERE user_id = (SELECT id FROM users WHERE primary_identifier = @pid LIMIT 1) ORDER BY id DESC', { ['@pid'] = primary })
	TriggerClientEvent('cz-character:response_characters', src, rows or {})
end

RegisterNetEvent('cz-character:request_characters')
AddEventHandler('cz-character:request_characters', function()
	local src = source
	CreateThread(function() handle_request_characters(src) end)
end)
if CZ_RPC and CZ_RPC.register then CZ_RPC.register('cz-character:request_characters', function(source) CreateThread(function() handle_request_characters(source) end); return { ok = true } end) end

local function handle_select_character(src, char_id)
	char_id = tonumber(char_id)
	if not char_id then TriggerClientEvent('cz-character:select_character:result', src, false, 'invalid id'); return end
	local ids = GetPlayerIdentifiers(src) or {}
	local primary = choose_primary_identifier(ids)
	if not primary then TriggerClientEvent('cz-character:select_character:result', src, false, 'no identifier'); return end

	local rows = db_query([[SELECT c.id as cid, u.id as uid FROM characters c JOIN users u ON c.user_id = u.id WHERE c.id = @cid AND u.primary_identifier = @pid LIMIT 1]], { ['@cid'] = char_id, ['@pid'] = primary })
	if not rows or #rows == 0 then TriggerClientEvent('cz-character:select_character:result', src, false, 'character not found'); return end
	local uid = rows[1].uid

	db_query('UPDATE characters SET is_active = CASE WHEN id = @cid THEN 1 ELSE 0 END WHERE user_id = @uid', { ['@cid'] = char_id, ['@uid'] = uid })

	-- if there was an infl session-like mapping, finalize play time for previous mapping
	local infl = sessions_by_source[src]
	if infl and infl.connect_ts and infl.user_id then
		local dur = math.max(0, os.time() - (infl.connect_ts or os.time()))
		db_query('UPDATE users SET total_play_seconds = total_play_seconds + @dur, last_seen = NOW() WHERE id = @uid', { ['@dur'] = dur, ['@uid'] = infl.user_id })
	end

	-- preserve any previously queued pending coords, then create an active mapping
	local existing = sessions_by_source[src]
	local pending = existing and existing.pending_start
	sessions_by_source[src] = { user_id = uid, character_id = char_id, connect_ts = os.time() }
	-- apply any pending start coords reported earlier directly to the character
	if pending then
		CreateThread(function()
			db_query('UPDATE characters SET last_x = @x, last_y = @y, last_z = @z WHERE id = @cid', { ['@x'] = pending.x, ['@y'] = pending.y, ['@z'] = pending.z, ['@cid'] = sessions_by_source[src].character_id })
		end)
	end

	-- fetch last known coords and instruct client to spawn there if available
	local lastpos = db_query('SELECT last_x, last_y, last_z FROM characters WHERE id = @cid LIMIT 1', { ['@cid'] = char_id })
	if lastpos and lastpos[1] then
		local lx = tonumber(lastpos[1].last_x) or 0
		local ly = tonumber(lastpos[1].last_y) or 0
		local lz = tonumber(lastpos[1].last_z) or 0
		TriggerClientEvent('cz-character:spawn_at', src, lx, ly, lz)
	end
	TriggerClientEvent('cz-character:select_character:result', src, true, 'ok')
end

RegisterNetEvent('cz-character:request_select_character')
AddEventHandler('cz-character:request_select_character', function(char_id)
	local src = source
	CreateThread(function() handle_select_character(src, char_id) end)
end)
if CZ_RPC and CZ_RPC.register then CZ_RPC.register('cz-character:request_select_character', function(source, char_id) CreateThread(function() handle_select_character(source, char_id) end); return { ok = true } end) end

RegisterNetEvent('cz-character:request_spawn_points')
AddEventHandler('cz-character:request_spawn_points', function()
	local src = source
	local sp = Config and Config.Character and Config.Character.SpawnPoints
	if sp then
		TriggerClientEvent('cz-character:spawn_points', src, sp)
	else
		TriggerClientEvent('cz-character:spawn_points', src, {})
	end
end)
if CZ_RPC and CZ_RPC.register then CZ_RPC.register('cz-character:request_spawn_points', function(source) return { ok = true, res = (Config and Config.Character and Config.Character.SpawnPoints) or {} } end) end

RegisterNetEvent('cz-character:request_edit_character')
AddEventHandler('cz-character:request_edit_character', function(char_id, first, last)
	local src = source
	char_id = tonumber(char_id)
	if not char_id then TriggerClientEvent('cz-character:edit_character:result', src, false, 'invalid id'); return end
	first = tostring(first or '')
	last = tostring(last or '')

	local ids = GetPlayerIdentifiers(src) or {}
	local primary = choose_primary_identifier(ids)
	if not primary then TriggerClientEvent('cz-character:edit_character:result', src, false, 'no identifier'); return end

	-- ensure the character belongs to this user
	local rows = db_query([[SELECT c.id as cid, u.id as uid FROM characters c JOIN users u ON c.user_id = u.id WHERE c.id = @cid AND u.primary_identifier = @pid LIMIT 1]], { ['@cid'] = char_id, ['@pid'] = primary })
	if not rows or #rows == 0 then TriggerClientEvent('cz-character:edit_character:result', src, false, 'character not found'); return end

	db_query('UPDATE characters SET first_name = @first, last_name = @last WHERE id = @cid', { ['@first'] = first, ['@last'] = last, ['@cid'] = char_id })
	TriggerClientEvent('cz-character:edit_character:result', src, true, 'ok')
end)
if CZ_RPC and CZ_RPC.register then CZ_RPC.register('cz-character:request_edit_character', function(source, char_id, first, last) CreateThread(function() TriggerEvent('cz-character:request_edit_character', char_id, first, last) end); return { ok = true } end) end

local function split_name(full)
	if not full or full == '' then return nil, nil end
	local parts = {}
	for part in tostring(full):gmatch('%S+') do table.insert(parts, part) end
	if #parts == 0 then return nil, nil end
	local first = parts[1]
	table.remove(parts, 1)
	local last = table.concat(parts, ' ')
	return first, (last ~= '' and last or nil)
end

local function upsert_player_and_session(src)
	local ids = GetPlayerIdentifiers(src) or {}
	local primary = choose_primary_identifier(ids)
	if not primary then return nil end
	local name = GetPlayerName(src) or ''
	local first, last = split_name(name)
	local id_json = json.encode(ids)

	local params = { ['@pid'] = primary, ['@ident'] = id_json, ['@name'] = name }
	local insert_sql = [[
		INSERT INTO users (primary_identifier, identifiers, name, last_seen)
		VALUES (@pid, @ident, @name, NOW())
		ON DUPLICATE KEY UPDATE identifiers = VALUES(identifiers), name = VALUES(name), last_seen = NOW();
	]]

	db_query(insert_sql, params)
	local rows = db_query('SELECT id FROM users WHERE primary_identifier = @pid LIMIT 1', { ['@pid'] = primary })
	if not rows or #rows == 0 then return end
	local user_id = rows[1].id
	local crows = db_query('SELECT id FROM characters WHERE user_id = @uid AND is_active = 1 ORDER BY id DESC LIMIT 1', { ['@uid'] = user_id })
	local char_id = nil
	if crows and #crows > 0 then
		char_id = crows[1].id
	else
			local sp = choose_spawn_point()
			db_query('INSERT INTO characters (user_id, created_at, last_x, last_y, last_z) VALUES (@uid, NOW(), @x, @y, @z)', { ['@uid'] = user_id, ['@x'] = sp.x, ['@y'] = sp.y, ['@z'] = sp.z })
		local nrows = db_query('SELECT id FROM characters WHERE user_id = @uid ORDER BY id DESC LIMIT 1', { ['@uid'] = user_id })
		if not nrows or #nrows == 0 then return end
		char_id = nrows[1].id
	end
	-- preserve any previously queued pending coords, then keep an in-memory mapping
	local existing = sessions_by_source[src]
	local pending = existing and existing.pending_start
	sessions_by_source[src] = { user_id = user_id, character_id = char_id, connect_ts = os.time() }
	if pending then
		CreateThread(function()
			db_query('UPDATE characters SET last_x = @x, last_y = @y, last_z = @z WHERE id = @cid', { ['@x'] = pending.x, ['@y'] = pending.y, ['@z'] = pending.z, ['@cid'] = sessions_by_source[src].character_id })
		end)
	end
	-- send configured spawn points to the client so spawnmanager can use the same list
	local sp = Config and Config.Character and Config.Character.SpawnPoints
	if sp then
		TriggerClientEvent('cz-character:spawn_points', src, sp)
	end
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals) local src = source; pcall(function() upsert_player_and_session(src) end) end)

AddEventHandler('playerDropped', function(reason)
	local src = source
	local infl = sessions_by_source[src]
	if not infl then return end
	local dur = math.max(0, os.time() - (infl.connect_ts or os.time()))
	-- attempt to persist last known coords (prefer last_coords, fallback to pending_start)
	local last = infl.last_coords or infl.pending_start
	CreateThread(function()
		if last and infl.character_id then
			pcall(function()
				db_query('UPDATE characters SET last_x = @x, last_y = @y, last_z = @z WHERE id = @cid', { ['@x'] = last.x, ['@y'] = last.y, ['@z'] = last.z, ['@cid'] = infl.character_id })
			end)
		end
		db_query('UPDATE users SET total_play_seconds = total_play_seconds + @dur, last_seen = NOW() WHERE id = @uid', { ['@dur'] = dur, ['@uid'] = infl.user_id })
		sessions_by_source[src] = nil
	end)
end)

RegisterNetEvent('cz-character:report_location')
AddEventHandler('cz-character:report_location', function(x, y, z)
	local src = source
	local infl = sessions_by_source[src]
	if infl and infl.character_id then
		-- remember last coords in-memory and persist to DB
		infl.last_coords = { x = x, y = y, z = z }
		CreateThread(function()
			db_query('UPDATE characters SET last_x = @x, last_y = @y, last_z = @z WHERE id = @cid', { ['@x'] = x, ['@y'] = y, ['@z'] = z, ['@cid'] = infl.character_id })
		end)
	else
		-- no mapping yet; store pending start coords to be applied when character is chosen
		sessions_by_source[src] = sessions_by_source[src] or {}
		sessions_by_source[src].pending_start = { x = x, y = y, z = z }
		Log.info(('Queued start coords for src=%s'):format(tostring(src)))
	end
end)

-- Create character handler
local function handle_create_character(src, first, last)
	first = tostring(first or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	last = tostring(last or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	if #first < 1 then TriggerClientEvent('cz-character:create_character:result', src, false, 'first name required'); return end
	if #first > 64 or #last > 64 then TriggerClientEvent('cz-character:create_character:result', src, false, 'name too long'); return end
	local ids = GetPlayerIdentifiers(src) or {}
	local primary = choose_primary_identifier(ids)
	if not primary then TriggerClientEvent('cz-character:create_character:result', src, false, 'no identifier'); return end
	local max_chars = (Config and Config.Character and Config.Character.max_characters) or 3

	local counts = db_query('SELECT COUNT(1) as cnt FROM characters WHERE user_id = (SELECT id FROM users WHERE primary_identifier = @pid LIMIT 1)', { ['@pid'] = primary })
	if counts and counts[1] and tonumber(counts[1].cnt) >= tonumber(max_chars) then TriggerClientEvent('cz-character:create_character:result', src, false, 'character limit reached'); return end

	local rows = db_query('SELECT id FROM users WHERE primary_identifier = @pid LIMIT 1', { ['@pid'] = primary })
	if not rows or #rows == 0 then TriggerClientEvent('cz-character:create_character:result', src, false, 'user not found'); return end
	local user_id = rows[1].id

	local sp = choose_spawn_point()
	db_query('UPDATE characters SET is_active = 0 WHERE user_id = @uid', { ['@uid'] = user_id })
	db_query('INSERT INTO characters (user_id, first_name, last_name, is_active, last_x, last_y, last_z) VALUES (@uid, @first, @last, 1, @x, @y, @z)', { ['@uid'] = user_id, ['@first'] = first, ['@last'] = last, ['@x'] = sp.x, ['@y'] = sp.y, ['@z'] = sp.z })
	local crows = db_query('SELECT id FROM characters WHERE user_id = @uid ORDER BY id DESC LIMIT 1', { ['@uid'] = user_id })
	if not crows or #crows == 0 then TriggerClientEvent('cz-character:create_character:result', src, false, 'create failed'); return end
	local char_id = crows[1].id
	TriggerClientEvent('cz-character:create_character:result', src, true, char_id)
end

RegisterNetEvent('cz-character:create_character')
AddEventHandler('cz-character:create_character', function(first, last)
	local src = source
	CreateThread(function() handle_create_character(src, first, last) end)
end)
if CZ_RPC and CZ_RPC.register then CZ_RPC.register('cz-character:create_character', function(source, first, last) CreateThread(function() handle_create_character(source, first, last) end); return { ok = true } end) end
