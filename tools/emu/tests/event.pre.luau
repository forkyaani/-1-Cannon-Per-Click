-- Before the server starts: a second event, to show that an event is only data. It ended an hour ago, pays one
-- rank in gems and uses the Halloween currency. (tests/event.luau)
local Shared = require(game:GetService("ReplicatedStorage").Shared.Features.Event)
local now = harness.now()
Shared.define({
	id = "emutest",
	name = "Emulator",
	currency = "candy",
	startsAt = now - 10 * 86_400,
	endsAt = now - 3_600,
	rewards = { { from = 1, to = 1, kind = "gems", amount = 100 } },
})
