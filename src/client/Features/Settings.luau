-- Settings, client side: the SETTINGS window with a switch for the music and one for the sounds. A switch
-- turns its mixer (UI.SoundGroups) up or down; the server keeps the choice in the save
-- (src/server/Features/Settings.luau), and what it says is applied on every change of the player's state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Settings"))

local ROW_HEIGHT = 76
local SWITCH = Vector2.new(120, 48)

local function start(ctx)
	local State, UI = ctx.State, ctx.UI

	local window = UI.window(Settings.WINDOW, 520, 150 + #Settings.Switches * (ROW_HEIGHT + 8))
	local list = UI.scroll(window.body, { Size = UDim2.fromScale(1, 1) })

	-- Until the server has answered, and for a key it does not send, the switch is on.
	local function isOn(key: string): boolean
		return State.feature("settings")[key] ~= false
	end

	local toggles = {}
	for order, switch in Settings.Switches do
		local row = UI.row(list, ROW_HEIGHT, order)
		row.icon.Visible = false
		row.title.Position = UDim2.fromOffset(16, 8)
		row.title.Size = UDim2.new(1, -SWITCH.X - 44, 0, 26)
		row.title.Text = switch.title
		row.sub.Position = UDim2.fromOffset(16, 36)
		row.sub.Size = UDim2.new(1, -SWITCH.X - 44, 0, ROW_HEIGHT - 44)
		row.sub.Text = switch.sub
		local toggle = UI.toggle({
			parent = row.frame,
			position = UDim2.new(1, -SWITCH.X - 14, 0.5, -SWITCH.Y / 2),
			size = SWITCH,
			textSize = 20,
		})
		toggle.button.Activated:Connect(function()
			-- Heard (or not) at once; the server's answer puts it right if the press was lost.
			UI.setAudio(switch.key, not isOn(switch.key))
			ctx.act("settingToggle", switch.key)
		end)
		toggles[switch.key] = toggle
	end

	local function refresh()
		for key, toggle in toggles do
			local on = isOn(key)
			UI.setAudio(key, on)
			toggle.set(on, if on then "ON" else "OFF", if on then UI.Variants.primary else UI.Variants.disabled)
		end
	end

	ctx.Windows.register(Settings.WINDOW, window, refresh)
	ctx.Hud.addMenuButton(Settings.WINDOW, Color3.fromRGB(150, 160, 185), 17, window.toggle)
	State.onChange(refresh)
	refresh()
end

return { start = start }
