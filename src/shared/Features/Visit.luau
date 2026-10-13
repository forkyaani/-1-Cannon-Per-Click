-- Visiting rules both sides read: a player goes to see somebody else's base with VISIT, unless that owner
-- switched Visitors off in SETTINGS (then only the owner's invitation gets them there).
-- The server half is src/server/Features/Visit.luau (it enforces these), the window src/client/Features/Visit.luau.
local Visit = {}

Visit.WINDOW = "VISIT" -- the window, and its menu button

Visit.InviteSeconds = 60 -- an invitation nobody answers goes away. There is no "no": ignoring it declines
Visit.InviteGapSeconds = 3 -- between two invitations from the same player
Visit.AgainSeconds = 30 -- after an invitation ran out, before the same player can be invited again
Visit.MaxIncoming = 5 -- invitations one player can have waiting
Visit.MaxOutgoing = 5 -- invitations one player can have out at a time

-- Visits without an invitation (visitGo).
Visit.PRIVATE = "Private" -- the Player attribute the server sets while that player's Visitors switch is off
Visit.SETTING = "visitors" -- the switch's key in the Settings feature's save
Visit.VisitGapSeconds = 5 -- between two uninvited visits by the same player
Visit.KickedSeconds = 120 -- after SEND HOME, before that guest can come back to that base uninvited
Visit.NoticeSeconds = 60 -- the owner is told "<name> is visiting" at most this often about the same visitor

return Visit
