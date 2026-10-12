-- The admin grant tool, client side: the ADMIN window. It only sends what was typed; the server decides who
-- is an admin and what may be granted (src/server/Features/Admin.luau) and answers in the result line.
-- The window and its menu button are made only once the server has said this player is an admin
-- (State.feature("admin").admin). That hides the button and nothing more: the server checks every call.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Admin = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"):WaitForChild("Admin"))

local WIDTH, HEIGHT = 580, 500
local ROW = 52 -- the height of a field
local GAP = 62 -- from one row of fields to the next
local LINE = 24 -- the height of a log line
local HINTS = 4 -- ids offered under the id box

local Feature = {}

function Feature.start(ctx)
	local UI, State = ctx.UI, ctx.State
	local built = false
	local refresh: () -> () = function() end

	local function build()
		local window = UI.window(Admin.WINDOW, WIDTH, HEIGHT)
		local kindIndex = 1
		local note: string? = nil -- what the window itself has to say (a field left empty), until the next answer
		local noteAt = 0 -- the server answer `note` was written over

		local function field(name: string, placeholder: string, position: UDim2, size: UDim2): TextBox
			local outline = UI.stroke(3)
			outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			return UI.make("TextBox", {
				Name = name,
				Position = position,
				Size = size,
				BackgroundColor3 = UI.Colors.cream,
				BorderSizePixel = 0,
				Font = UI.FONT,
				Text = "",
				PlaceholderText = placeholder,
				PlaceholderColor3 = UI.Colors.grey,
				TextColor3 = UI.Colors.ink,
				TextSize = 22,
				ClearTextOnFocus = false,
				Parent = window.body,
			}, { UI.corner(14), outline })
		end

		local nameBox = field("Player", "PLAYER NAME OR USER ID", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, ROW))
		local kindButton = UI.button({
			Name = "Kind",
			Position = UDim2.fromOffset(8, GAP),
			Size = UDim2.fromOffset(300, ROW),
			Text = "",
			BackgroundColor3 = Color3.fromRGB(90, 150, 255),
			Parent = window.body,
		})
		local amountBox = field("Amount", "AMOUNT", UDim2.fromOffset(318, GAP), UDim2.new(1, -326, 0, ROW))
		local idBox = field("Id", "ID", UDim2.fromOffset(8, GAP * 2), UDim2.new(1, -16, 0, ROW))
		local hint = UI.text({
			Name = "Hint",
			Position = UDim2.fromOffset(8, GAP * 2 + ROW + 2),
			Size = UDim2.new(1, -16, 0, 22),
			Text = "",
			TextColor3 = UI.Colors.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 16,
			Parent = window.body,
		})
		local result = UI.text({
			Name = "Result",
			Position = UDim2.fromOffset(8, GAP * 3 + 22),
			Size = UDim2.new(1, -196, 0, ROW),
			Text = "",
			TextColor3 = UI.Colors.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			MaxSize = 18,
			Parent = window.body,
		})
		local grant = UI.button({
			Name = "Grant",
			Position = UDim2.new(1, -178, 0, GAP * 3 + 22),
			Size = UDim2.fromOffset(170, ROW),
			Text = "GRANT",
			BackgroundColor3 = UI.Colors.green,
			Parent = window.body,
		})
		local logTop = GAP * 4 + 30
		UI.text({
			Position = UDim2.fromOffset(8, logTop),
			Size = UDim2.new(1, -16, 0, LINE),
			Text = "LAST GRANTS",
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxSize = 18,
			Parent = window.body,
		})
		local lines = {}
		for index = 1, Admin.LOG_SHOWN do
			lines[index] = UI.text({
				Name = "Log" .. index,
				Position = UDim2.fromOffset(8, logTop + index * LINE),
				Size = UDim2.new(1, -16, 0, LINE),
				Text = "",
				TextColor3 = UI.Colors.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxSize = 15,
				Parent = window.body,
			})
		end

		-- The ids of the picked kind that hold what is typed, a few of them: nobody knows every id by heart.
		local function hints(kind, typed: string): string
			if not kind.needsId then
				return ""
			end
			local all = if kind.id == "item" then ctx.Items.all() else ctx.Config.Pets
			local exact = all[typed]
			if exact then
				return `That is: {exact.name}`
			end
			local found = {}
			local needle = string.lower(typed)
			for id in all do
				if typeof(id) == "string" and (needle == "" or string.find(string.lower(id), needle, 1, true)) then
					table.insert(found, id)
				end
			end
			if #found == 0 then
				return "No id like that"
			end
			table.sort(found)
			local more = #found - HINTS
			for _ = 1, more do
				table.remove(found)
			end
			return "Ids: " .. table.concat(found, ", ") .. (if more > 0 then `, and {more} more` else "")
		end

		local function ago(at: any): string
			local seconds = if typeof(at) == "number" then math.max(0, State.now() - at) else 0
			if seconds < 90 then
				return "just now"
			elseif seconds < 5400 then
				return `{math.floor(seconds / 60)}m ago`
			elseif seconds < 129_600 then
				return `{math.floor(seconds / 3600)}h ago`
			end
			return `{math.floor(seconds / 86_400)}d ago`
		end

		-- The fields: redrawn when the kind or the id changes, not with every state change.
		local function drawFields()
			local kind = Admin.KINDS[kindIndex]
			kindButton.Text = "WHAT: " .. kind.name
			idBox.Visible = kind.needsId == true
			hint.Text = hints(kind, idBox.Text)
			amountBox.PlaceholderText = `AMOUNT (1 TO {ctx.Format.abbreviate(kind.cap)})`
		end

		-- The server's answer and the log.
		local function draw()
			local state = State.feature("admin")
			local answer = state.result
			local answered = if typeof(answer) == "table" and typeof(answer.n) == "number" then answer.n else 0
			if note and answered == noteAt then
				result.Text = note
				result.TextColor3 = UI.Colors.red
			elseif typeof(answer) == "table" and typeof(answer.text) == "string" then
				note = nil
				result.Text = answer.text
				result.TextColor3 = if answer.ok then UI.Colors.green else UI.Colors.red
			else
				result.Text = ""
			end

			-- The newest first.
			local log = if typeof(state.log) == "table" then state.log else {}
			for index, text in lines do
				local entry = log[#log - index + 1]
				text.Text = if typeof(entry) == "table" then `{ago(entry.at)}: {tostring(entry.text)}` else ""
			end
		end

		local function say(text: string)
			local answer = State.feature("admin").result
			note = text
			noteAt = if typeof(answer) == "table" and typeof(answer.n) == "number" then answer.n else 0
			draw()
		end

		kindButton.Activated:Connect(function()
			kindIndex = kindIndex % #Admin.KINDS + 1
			drawFields()
		end)
		idBox:GetPropertyChangedSignal("Text"):Connect(function()
			if #idBox.Text > Admin.ID_MAX then
				idBox.Text = string.sub(idBox.Text, 1, Admin.ID_MAX)
			end
			drawFields()
		end)
		grant.Activated:Connect(function()
			local kind = Admin.KINDS[kindIndex]
			local target = string.match(nameBox.Text, "^%s*(.-)%s*$") or ""
			local id = string.match(idBox.Text, "^%s*(.-)%s*$") or ""
			-- "1,000" and "1 000" are numbers too.
			local amount = tonumber((string.gsub(amountBox.Text, "[%s,]", "")))
			if target == "" then
				say("Type the player's name or user id")
			elseif not amount then
				say("Type an amount")
			elseif kind.needsId and id == "" then
				say("Type the id of the thing to grant")
			else
				note = nil
				result.Text = "Sending..."
				ctx.act("adminGrant", { target = target, kind = kind.id, id = if kind.needsId then id else nil, amount = amount })
			end
		end)

		Feature.window, Feature.nameBox, Feature.kindButton = window, nameBox, kindButton -- for tests
		Feature.amountBox, Feature.idBox, Feature.grant = amountBox, idBox, grant
		Feature.result, Feature.lines, Feature.hint = result, lines, hint
		refresh = draw
		drawFields()
		draw()
		ctx.Windows.register(Admin.WINDOW, window, draw)
		Feature.button = ctx.Hud.addMenuButton(Admin.WINDOW, Color3.fromRGB(120, 120, 140), 90, window.toggle)
	end

	-- The server's word may arrive after this starts: look again whenever the state changes.
	local function look()
		if not built and State.feature("admin").admin == true then
			built = true
			build()
		end
		if built then
			refresh()
		end
	end
	look()
	State.onChange(look)
end

return Feature
