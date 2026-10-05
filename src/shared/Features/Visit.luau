-- Visiting rules both sides read: bases are private, and a player reaches somebody else's only by invitation.
-- The server half is src/server/Features/Visit.luau (it enforces these), the window src/client/Features/Visit.luau.
local Visit = {}

Visit.WINDOW = "VISIT" -- the window, and its menu button

Visit.InviteSeconds = 60 -- an invitation nobody answers goes away. There is no "no": ignoring it declines
Visit.InviteGapSeconds = 3 -- between two invitations from the same player
Visit.AgainSeconds = 30 -- after an invitation ran out, before the same player can be invited again
Visit.MaxIncoming = 5 -- invitations one player can have waiting
Visit.MaxOutgoing = 5 -- invitations one player can have out at a time

return Visit
