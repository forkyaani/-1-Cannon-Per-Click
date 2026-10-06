-- Redeem codes, client side: the CODES window, a text box and a REDEEM button. It only sends what was typed;
-- the server decides (src/server/Features/Codes.luau) and answers with a toast, good or bad.
-- The window opens from its menu button and from nothing else.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Codes"))

local BUTTON = Vector2.new(150, 56)

local Feature = {}

function Feature.start(ctx)
	local UI = ctx.UI

	local window = UI.window(Codes.WINDOW, 520, 230)
	UI.text({
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 44),
		Text = "Got a code? Type it here. Each code works once.",
		TextColor3 = UI.Colors.text,
		TextWrapped = true,
		MaxSize = 20,
		Parent = window.body,
	})
	local outline = UI.stroke(3)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local box: TextBox = UI.make("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(8, 56),
		Size = UDim2.new(1, -BUTTON.X - 28, 0, BUTTON.Y),
		BackgroundColor3 = UI.Colors.cream,
		BorderSizePixel = 0,
		Font = UI.FONT,
		Text = "",
		PlaceholderText = "CODE",
		PlaceholderColor3 = UI.Colors.grey,
		TextColor3 = UI.Colors.ink,
		TextSize = 26,
		ClearTextOnFocus = false,
		Parent = window.body,
	}, { UI.corner(14), outline })
	local button = UI.button({
		Name = "Redeem",
		Position = UDim2.new(1, -BUTTON.X - 8, 0, 56),
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		Text = "REDEEM",
		BackgroundColor3 = UI.Colors.green,
		Parent = window.body,
	})

	-- A text far too long is cut as it is typed (a paste), so the box never holds more than a code.
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Codes.MAX_LENGTH then
			box.Text = string.sub(box.Text, 1, Codes.MAX_LENGTH)
		end
	end)

	local function redeem()
		local text = box.Text
		if string.match(text, "^%s*$") then
			return
		end
		box.Text = ""
		ctx.act("redeemCode", text)
	end
	button.Activated:Connect(redeem)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			redeem()
		end
	end)

	Feature.box, Feature.button = box, button -- for tests
	ctx.Windows.register(Codes.WINDOW, window, function() end)
	ctx.Hud.addMenuButton(Codes.WINDOW, Color3.fromRGB(95, 200, 120), 18, window.toggle)
end

return Feature
