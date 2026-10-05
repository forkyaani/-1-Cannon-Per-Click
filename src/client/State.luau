-- Read-only view of what the server tells this client about its own player.
-- Hot numbers arrive as player attributes; everything else as one JSON attribute called Meta.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local State = { meta = {} }

local listeners = {}
local pending = false
local featureCache = {}

function State.get(name: string, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

-- A feature's own state, sent by the server with Game.setMeta(player, key, value). Always a table.
function State.feature(key: string)
	local name = "Meta_" .. key
	local cached = featureCache[name]
	if not cached then
		cached = {}
		local raw = player:GetAttribute(name)
		if typeof(raw) == "string" then
			local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and typeof(result) == "table" then
				cached = result
			end
		end
		featureCache[name] = cached
	end
	return cached
end

-- Server clock in unix seconds, for countdowns.
function State.now(): number
	return workspace:GetServerTimeNow()
end

-- callback runs (at most once per frame) after any state change.
function State.onChange(callback: () -> ())
	table.insert(listeners, callback)
end

local function decodeMeta()
	local raw = player:GetAttribute("Meta")
	if typeof(raw) ~= "string" then
		return
	end
	local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and typeof(result) == "table" then
		State.meta = result
	end
end

local function schedule()
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		for _, callback in listeners do
			task.spawn(callback)
		end
	end)
end

player.AttributeChanged:Connect(function(name: string)
	if name == "Meta" then
		decodeMeta()
	elseif string.sub(name, 1, 5) == "Meta_" then
		featureCache[name] = nil
	end
	schedule()
end)
decodeMeta()

return State
