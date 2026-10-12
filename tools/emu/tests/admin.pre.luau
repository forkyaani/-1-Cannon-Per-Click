-- Runs before the server starts: the test's own player (user 1) is an admin, as an account in Admin.IDS is.
local Admin = require(game:GetService("ReplicatedStorage").Shared.Features.Admin)
Admin.IDS[1] = "Tester"
