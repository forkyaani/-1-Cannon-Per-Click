-- Shared helpers for the test chunks: one player, the toasts they are sent, and shorthands for the remotes.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService").Server

local T = {}

T.Game = require(Server.Game)
T.Config = require(ReplicatedStorage.Shared.Config)
T.Format = require(ReplicatedStorage.Shared.Format)
T.Items = require(ReplicatedStorage.Shared.Items)
T.Powerups = require(ReplicatedStorage.Shared.Features.Powerups)
T.Layout = require(ReplicatedStorage.Shared.Layout)
T.Marketplace = require(Server.Marketplace)
T.Plots = require(Server.Plots)
T.Remotes = ReplicatedStorage.Remotes

T.player = harness.addPlayer("Tester", 1)
T.data = T.Game.data(T.player)
-- The tests were written when a Studio session owned every pass: give them all, as the Debug remote can.
-- (A test that switches Studio off, session.luau, has no Debug remote: its player owns no pass, as it wants.)
if T.Remotes:FindFirstChild("Debug") then
	for key in T.Config.Passes do
		T.Remotes.Debug:FireServer("pass:" .. key, 1)
	end
end
harness.flush()
T.state = T.Game.state(T.player)
assert(T.data and T.state, "the player did not load")
-- The tests were written when a new save's level ran behind the welcome cards. The plot now waits for them
-- (Features/Tutorial.luau): let it go, the way the PAUSED banner can. tutorial.luau keeps the wait, its .pre
-- file says so. `T.held` is whether the join paused the plot.
T.held = T.state.paused == true
function T.release(who: Player)
	local state = T.Game.state(who)
	if state and state.paused then
		T.Game.actions.setPaused(who, T.Game.data(who), state, false)
	end
end
if not harness.keepWelcomeHold then
	T.release(T.player)
end

T.toasts = {}
T.Remotes.Notify.OnClientEvent:Connect(function(text: string, kind: string)
	table.insert(T.toasts, { text = text, kind = kind })
	print(`    toast [{kind}] {text}`)
end)

T.checks = 0
function T.check(condition, what: string)
	if not condition then
		error("CHECK FAILED: " .. what)
	end
	T.checks += 1
	print("  ok: " .. what)
end

function T.eq(actual, expected, what: string)
	if actual ~= expected then
		error(`CHECK FAILED: {what}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
	T.checks += 1
	print(`  ok: {what} = {tostring(actual)}`)
end

-- A client request, spaced past the server's action cooldown.
function T.act(name: string, argument: any?)
	harness.advance(0.1)
	T.Remotes.Action:FireServer(name, argument)
	harness.flush()
end

function T.debug(field: string, value: number)
	T.Remotes.Debug:FireServer(field, value)
	harness.flush()
end

-- Lets the game run: `seconds` of fighting, in half-second frames.
function T.run(seconds: number)
	for _ = 1, math.ceil(seconds * 2) do
		harness.step(0.5)
	end
end

function T.lastToast(): string
	local last = T.toasts[#T.toasts]
	return if last then last.text else ""
end

-- What the client is told about the backpack.
function T.items()
	return HttpService:JSONDecode(T.player:GetAttribute("Meta_items"))
end

function T.count(id: string): number
	return T.items()[id] or 0
end

function T.meta()
	return HttpService:JSONDecode(T.player:GetAttribute("Meta"))
end

function T.section(name: string)
	print("== " .. name)
end

return T
