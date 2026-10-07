-- The egg's opening in the hatch reveal (Effects.opening in src/client/Effects.luau), played a frame at a time:
-- the emulator cannot wait, so Effects.hatch itself is only started here, not played through.
-- Run with: python3 run.py --all-features tests/hatch_open.luau   (hatch_open.pre.luau puts the stand-in models in)
local T = harness.load("_prelude.luau")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = T.Config
local player = T.player
local check, eq = T.check, T.eq

harness.runClient()
local Client = player.PlayerScripts.Client
local Effects = require(Client.Effects)
local Models = require(ReplicatedStorage.Shared.Models)
local opening = Effects.opening
local SECONDS = opening.seconds

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-3
end
-- A stage as Effects.hatch makes one: the egg in a model, a camera, the mini cannon that is inside.
local function stageFor(eggId: string, petId: string, rare: Color3?)
	local scene = Instance.new("Model")
	local egg = opening.piece("EggModels", eggId)
	assert(egg, "the stand-in egg is missing")
	egg.Parent = scene
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(-5, 6, -12), Vector3.new(0, 2, 0))
	local mini = Models.mini(Config.Pets[petId], 1)
	assert(mini, "the stand-in mini cannon is missing")
	return { scene = scene, egg = egg, height = egg.Size.Y, camera = camera, mini = mini, miniSize = mini.Size, rare = rare }
end
local function count(scene: Instance, class: string): number
	local n = 0
	for _, child in scene:GetChildren() do
		if child:IsA(class) then
			n += 1
		end
	end
	return n
end

T.section("an egg with halves")
do
	local stage = stageFor("basicegg", "wooden")
	local egg, full = stage.egg, stage.miniSize
	opening.begin(stage, "basicegg", Color3.new(0.4, 0.8, 0.3), 1)
	check(egg.Parent == nil, "the whole egg is gone")
	check(stage.top.Name == "basicegg_Top" and stage.bottom.Name == "basicegg_Bottom", "its two halves stand in its place")
	check(stage.top.Parent == stage.scene and stage.bottom.Parent == stage.scene, "on the stage")
	eq(count(stage.scene, "WedgePart"), 9, "nine pieces of shell")
	check(stage.mini.Parent == stage.scene, "the mini cannon is on the stage")
	check(near(stage.mini.Size.X, full.X * 0.3), "small, inside the shell")
	check(stage.mini:GetPivot().Position.Y < stage.height * 0.54, "below the crack")

	-- Played through in twenty frames.
	local topHigh, miniHigh, last = -math.huge, -math.huge, nil
	for frame = 0, 20 do
		local t = SECONDS * frame / 20
		opening.step(stage, t)
		topHigh = math.max(topHigh, stage.top:GetPivot().Position.Y)
		miniHigh = math.max(miniHigh, stage.mini:GetPivot().Position.Y)
		last = t
	end
	eq(last, SECONDS, "the last frame is the end")
	check(topHigh > stage.height * 0.2, `the top was thrown up ({topHigh})`)
	check(stage.top:GetPivot().Position.Y < 0 and stage.top:GetPivot().Position.X > stage.height * 0.5, "and has fallen away to one side")
	eq(stage.top.Transparency, 1, "faded out")
	eq(stage.bottom.Transparency, 1, "the bottom half too")
	check(stage.bottom:GetPivot().Position.Y < 0, "sunk under where it stood")
	check(miniHigh > stage.rest.Y + stage.height * 0.2, `the mini cannon jumped higher than where it lands ({miniHigh})`)
	check(near(stage.mini:GetPivot().Position.Y, stage.rest.Y), "and landed where the egg's middle was")
	check(near(stage.mini.Size.X, full.X) and near(stage.mini.Size.Y, full.Y), "at its full size")
	for _, shard in stage.shards do
		check((shard.part.Position - shard.from).Magnitude > stage.height * 0.5, "a piece of shell flew out")
		eq(shard.part.Transparency, 1, "and faded")
	end
	check((stage.camera.CFrame.Position - stage.cameraTo.Position).Magnitude < 1e-3, "the camera has moved to the mini cannon")

	local top, bottom, mini = stage.top, stage.bottom, stage.mini
	opening.finish(stage)
	check(top.Parent == nil and bottom.Parent == nil, "the shell is cleared away")
	eq(count(stage.scene, "WedgePart"), 0, "every piece of it")
	check(mini.Parent == stage.scene, "the mini cannon stays")
	check(near(mini:GetPivot().Position.Y, stage.rest.Y), "where the egg's middle was")
	check(stage.rays == nil, "no rays for an ordinary one")
end

T.section("an egg without halves")
do
	local stage = stageFor("forestegg", "leaf")
	local egg = stage.egg
	opening.begin(stage, "forestegg", Color3.new(0.2, 0.6, 0.3), 2)
	check(stage.top == egg and stage.bottom == nil, "the whole shell is what flies off")
	check(egg.Parent == stage.scene, "it is still on the stage")
	for frame = 0, 10 do
		opening.step(stage, SECONDS * frame / 10)
	end
	check(egg:GetPivot().Position.X < 0, "the second egg's shell goes the other way")
	eq(egg.Transparency, 1, "and fades")
	opening.finish(stage)
	check(egg.Parent == nil, "then it is gone")
	check(stage.mini.Parent == stage.scene, "and the mini cannon stands alone")
end

T.section("a Secret or a Huge")
do
	local gold = Color3.new(1, 0.8, 0.1)
	local stage = stageFor("basicegg", "iron", gold)
	opening.begin(stage, "basicegg", Color3.new(0.4, 0.8, 0.3), 1)
	opening.step(stage, SECONDS)
	opening.finish(stage)
	check(stage.rays ~= nil and #stage.rays == 10, "ten rays behind it")
	local first = stage.rays[1].part.Position
	check(stage.rays[1].part.Color == gold, "in its rarity's colour")
	-- Behind the mini cannon as the camera sees it.
	local toCamera = (stage.cameraTo.Position - stage.rest).Unit
	check((first - stage.rest):Dot(toCamera) < 0, "behind the mini cannon, away from the camera")
	opening.turnRays(stage, 1) -- (the emulator's CFrames carry no rotation, so only that it runs is checked)
end

T.section("Effects.hatch starts with the modelled egg on its stage")
do
	local gui = player.PlayerGui
	-- In a thread of its own: the reveal waits for its first swing, and here a wait never ends.
	task.spawn(Effects.hatch, "basicegg", { { pet = "wooden", kept = true } })
	harness.flush()
	local viewports, staged = 0, 0
	for _, item in gui:GetDescendants() do
		if item:IsA("ViewportFrame") then
			viewports += 1
			for _, child in item:GetChildren() do
				if child:IsA("Model") and child:FindFirstChild("basicegg") then
					staged += 1
				end
			end
		end
	end
	check(viewports > 0, "the reveal has its pictures")
	eq(staged, 1, "the egg stands in one of them, inside its stage")
end

eq(harness.errors(), 0, "errors in spawned threads")
print(`{T.checks} checks`)
