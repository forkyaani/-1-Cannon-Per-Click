-- Client side of the marketplace: the look of every prompt, prompts that open windows or the loot viewer, and
-- each player's own price line on the egg stands. (The Hatch prompts and the return portal are handled by the
-- server.) Nothing opens by itself at an egg: its three prompts show, and F ("What's inside?") opens the loot
-- viewer on it.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Loot = require(script.Parent.Loot)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Colors = UI.Colors
local hex = Color3.fromHex

local Market = {}

local ICONS = { coins = "💰", diamonds = "💎", candy = "🍬" }
local BALANCE_ATTRIBUTE = { coins = "Coins", diamonds = "Diamonds", candy = "Candy" }

----------------------------------------------------------------------------------------------------
-- Prompts: the server makes them with the Custom style, so Roblox draws nothing and this does.
-- A dark pill with the key on a cream cap (keyboard and gamepad) and the action in capitals.
----------------------------------------------------------------------------------------------------
local PROMPT_LOOK = { top = hex("#4A2A70"), bottom = Colors.ink, lip = hex("#160826") }
local PROMPT_HEIGHT = 64
local GAMEPAD_NAMES = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
}
local promptGuis: { [ProximityPrompt]: BillboardGui } = {}

local function keyName(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Keyboard then
		local name = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
		return if name ~= "" then string.upper(name) else prompt.KeyboardKeyCode.Name
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_NAMES[prompt.GamepadKeyCode] or ""
	end
	return "" -- touch: the pill itself is the button
end

local function hidePrompt(prompt: ProximityPrompt)
	local gui = promptGuis[prompt]
	if gui then
		promptGuis[prompt] = nil
		gui:Destroy()
	end
end

local function showPrompt(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or promptGuis[prompt] then
		return
	end
	local s = UI.scale()
	local action = string.upper(prompt.ActionText)
	-- An egg's three prompts stand side by side under its sign, which names it: they say the action only.
	local text = if prompt:GetAttribute("EggId") then action else `{action} {string.upper(prompt.ObjectText)}`
	local key = keyName(prompt, inputType)
	local cap = if key ~= "" then 56 else 0
	local width = TextService:GetTextSize(text, 28, UI.FONT, Vector2.new(1000, PROMPT_HEIGHT)).X + cap + 52
	local height = PROMPT_HEIGHT + 6

	local gui: BillboardGui = UI.make("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Active = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Size = UDim2.fromOffset(width * s, height * s),
		-- UIOffset is in pixels of a 720px tall screen here: it shrinks with everything else on a phone.
		SizeOffset = Vector2.new(prompt.UIOffset.X / width, prompt.UIOffset.Y / height),
		Parent = playerGui,
	})
	local button = UI.make("TextButton", {
		Size = UDim2.fromOffset(width, PROMPT_HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = gui,
	}, { UI.make("UIScale", { Scale = s }) })
	local sticker = UI.sticker(button, PROMPT_LOOK, { radius = PROMPT_HEIGHT, lip = 5, outline = 3, gloss = false });
	(sticker.lip:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Colors.cream
	if key ~= "" then
		UI.chip({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(46, 42), Parent = sticker.face }, {
			UI.label({ Size = UDim2.fromScale(1, 1), Text = key, TextSize = 28, TextColor3 = Colors.ink, Stroke = 0 }),
		})
	end
	UI.label({
		Position = UDim2.fromOffset(cap + 10, 0),
		Size = UDim2.new(1, -cap - 20, 1, -2),
		Text = text,
		TextSize = 28,
		Parent = sticker.face,
	})

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) and prompt.ClickablePrompt then
			prompt:InputHoldBegin()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			prompt:InputHoldEnd()
		end
	end)
	promptGuis[prompt] = gui
	-- The texts change while the player stands there (Buy pad, then Build, then Upgrade): draw the pill again.
	local function redraw()
		if promptGuis[prompt] == gui then
			prompt:InputHoldEnd() -- a finger still on the old pill would never end its press
			hidePrompt(prompt)
			showPrompt(prompt, inputType)
		end
	end
	local actionChanged = prompt:GetPropertyChangedSignal("ActionText"):Connect(redraw)
	local objectChanged = prompt:GetPropertyChangedSignal("ObjectText"):Connect(redraw)
	gui.Destroying:Connect(function()
		actionChanged:Disconnect()
		objectChanged:Disconnect()
	end)
end

----------------------------------------------------------------------------------------------------
-- Stalls, the daily chest and the missions board carry a Window attribute naming the window they open.
-- A prompt with a Loot attribute opens the loot viewer on that source: an egg stand's "What's inside?".
function Market.start(openWindow: (name: string) -> ())
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		local window = prompt:GetAttribute("Window")
		local loot = prompt:GetAttribute("Loot")
		if typeof(window) == "string" then
			openWindow(window)
		elseif typeof(loot) == "string" then
			Loot.open(loot)
		end
	end)
	-- A stand that streamed in after the last state change still shows the server's placeholder text, and a
	-- prompt appearing means the player has walked up to something: either way, make the stands' text their own.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
		showPrompt(prompt, inputType)
		Market.refresh()
	end)
	ProximityPromptService.PromptHidden:Connect(hidePrompt)
end

-- The egg on its stand, or nil while that part of the map has not streamed in. Its signs hang on it.
local function standEgg(eggId: string): Instance?
	local market = workspace:FindFirstChild("Marketplace")
	local eggs = market and market:FindFirstChild("Eggs")
	local stand = eggs and eggs:FindFirstChild("Egg_" .. eggId)
	return stand and stand:FindFirstChild("Egg")
end

local function setStatus(gui: BillboardGui, text: string, color: Color3)
	local status = gui:FindFirstChild("Status") :: TextLabel?
	if status then
		status.Text = text
		status.TextColor3 = color
	end
end

-- Each player sees their own line on every egg stand's sign: locked, affordable or too expensive.
function Market.refresh()
	-- The stands are out of sight from the base, and this runs on every state change.
	if State.get("InMarket", false) ~= true then
		return
	end
	local best = State.get("BestCleared", 0)
	-- A prompt that streamed out while it was showing never says it was hidden.
	for prompt in promptGuis do
		if not prompt.Parent then
			hidePrompt(prompt)
		end
	end
	for _, egg in Config.Eggs do
		local shell = standEgg(egg.id)
		local sign = shell and shell:FindFirstChild("Sign") :: BillboardGui?
		if not sign then
			continue
		end
		if best < egg.unlock then
			setStatus(sign, `🔒 Clear {Config.waveLabel(egg.unlock)}`, Colors.red)
		else
			local affordable = State.get(BALANCE_ATTRIBUTE[egg.currency], 0) >= egg.cost
			setStatus(sign, `{Format.abbreviate(egg.cost)} {ICONS[egg.currency]}`, if affordable then Colors.green else Colors.white)
		end
	end
end

return Market
