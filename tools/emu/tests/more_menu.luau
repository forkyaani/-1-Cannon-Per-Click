-- The drawer behind MORE (run with --all-features): it opens in the middle of the screen, wider than tall, so
-- every button is on the screen in both views; a press outside closes it.
local T = harness.load("_prelude.luau")
local player = T.player
local check, eq = T.check, T.eq

harness.runClient()
local gui = player.PlayerGui
local drawer = gui:FindFirstChild("Drawer", true)
local backdrop = gui:FindFirstChild("DrawerBackdrop", true)
local more = gui:FindFirstChild("MORE", true)
check(drawer ~= nil and backdrop ~= nil and more ~= nil, "the drawer, its backdrop and MORE exist")
local UI = require(player.PlayerScripts.Client.UI)
local Hud = require(player.PlayerScripts.Client.Hud)

local function buttons(): number
	local count = 0
	for name, button in Hud.menu do
		if button.Visible and button:IsDescendantOf(drawer) then
			count += 1
		end
	end
	return count
end

local function standsInTheMiddle(view: string)
	eq(drawer.AnchorPoint, Vector2.new(0.5, 0.5), `{view}: anchored by its middle`)
	eq(drawer.Position, UDim2.fromScale(0.5, 0.5), `{view}: in the middle of the screen`)
	local size = drawer.Size
	check(size.Y.Offset <= 600, `{view}: fits a 720-high screen ({size.Y.Offset})`)
	check(size.X.Offset >= size.Y.Offset, `{view}: wider than tall ({size.X.Offset} x {size.Y.Offset})`)
	check(buttons() > 5, `{view}: the buttons are in it ({buttons()})`)
end

-- The emulator's screen is 100 wide. Give it a real one (only the emulator lets a test write this), and a
-- change of view to lay the HUD out again.
UI.gui.AbsoluteSize = Vector2.new(1280, 720) * UI.scale()
Hud.setMode(true)
Hud.setMode(false)
eq(UI.W(), 1280, "the screen is 1280 wide")

T.section("at the cannon")
eq(drawer.Visible, false, "closed to begin with")
harness.click(more)
eq(drawer.Visible, true, "MORE opens it")
eq(backdrop.Visible, true, "with the backdrop behind it")
standsInTheMiddle("cannon")
harness.click(backdrop)
eq(drawer.Visible, false, "a press outside closes it")

T.section("in the marketplace")
Hud.setMode(true)
harness.click(more)
eq(drawer.Visible, true, "MORE opens it")
standsInTheMiddle("market")
harness.click(more)
eq(drawer.Visible, false, "MORE closes it again")
Hud.setMode(false)

T.section("on a narrow screen")
UI.gui.AbsoluteSize = Vector2.new(420, 720) * UI.scale()
Hud.setMode(true)
Hud.setMode(false)
harness.click(more)
check(drawer.Size.X.Offset <= 420, `no wider than the screen ({drawer.Size.X.Offset})`)
harness.click(more)

-- Notifications are not shown over the open drawer (on a phone they covered its buttons).
local notices = gui:FindFirstChild("Notifications", true)
check(notices ~= nil and notices.Visible == true, "the notifications show while the drawer is shut")
harness.click(more)
eq(notices.Visible, false, "and not while it is open")
harness.click(backdrop)
eq(notices.Visible, true, "and again once it is shut")

check(harness.errors() == 0, "no errors")
print(`{T.checks} checks passed`)
