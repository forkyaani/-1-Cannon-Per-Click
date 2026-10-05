-- Where things sit: the plots (path, pads, spawn) and the marketplace. Shared so the client can place its
-- monsters and effects where the server simulates them.
local Layout = {}

-- The entry for any index: past the end the list wraps around, so a lookup never comes back nil.
local function wrapped(list: { Vector3 }, index: number): Vector3
	return list[(index - 1) % #list + 1]
end

----------------------------------------------------------------------------------------------------
-- Marketplace: a walkable town square far from every base.
----------------------------------------------------------------------------------------------------
Layout.MARKET_CENTER = Vector3.new(0, 0, -600)
Layout.MARKET_SIZE = 150

-- Where mini cannons hover while following their owner, on the plot and in the marketplace (owner's space,
-- +Z is behind).
-- Two wings fan out behind the shoulders, each three columns of two, filled from the owner outwards.
-- Straight behind the owner there are only two low ones, and nothing is higher than the owner's head, so a
-- camera behind them still sees the owner, the egg stand in front and its odds sign.
local MINI_FOLLOW = {
	Vector3.new(-2.6, 1.5, 3.4),
	Vector3.new(2.6, 1.5, 3.4),
	Vector3.new(0, -1.1, 4.8), -- at the owner's heels
	Vector3.new(-2.6, -1.1, 3.4),
	Vector3.new(2.6, -1.1, 3.4),
	Vector3.new(-4.8, 1.8, 3.8),
	Vector3.new(4.8, 1.8, 3.8),
	Vector3.new(-4.8, -0.8, 3.8),
	Vector3.new(4.8, -0.8, 3.8),
	Vector3.new(-7, 2.1, 4.2),
	Vector3.new(7, 2.1, 4.2),
	Vector3.new(-7, -0.5, 4.2),
	Vector3.new(7, -0.5, 4.2),
	Vector3.new(0, -1.1, 7.7), -- trails behind the one at the heels
}

function Layout.marketCFrame(): CFrame
	return CFrame.new(Layout.MARKET_CENTER)
end

-- Where players arrive: the south side of the square, facing the statue in the middle.
function Layout.marketSpawn(): CFrame
	local position = Layout.MARKET_CENTER + Vector3.new(0, 3.2, 56)
	return CFrame.lookAt(position, position - Vector3.zAxis)
end

function Layout.miniFollow(index: number): Vector3
	return wrapped(MINI_FOLLOW, index)
end

----------------------------------------------------------------------------------------------------
-- World islands: one round island per world (Config.Worlds), in two rows of six far from every base, so
-- nothing of an island shows from a base or from the marketplace. src/server/Islands.luau builds them.
-- Island space: the middle of the island is the origin, x east, z south, the ground's top at y = 0. Players
-- arrive in the middle and look north, at the eggs; everything to use stands in a ring around them.
----------------------------------------------------------------------------------------------------
Layout.ISLAND_COUNT = 12
Layout.ISLAND_RADIUS = 58
Layout.ISLAND_SPACING = 420 -- from one island's middle to the next
Layout.ISLAND_ORIGIN = Vector3.new(0, 0, 1200) -- the middle of the two rows

-- The middle of a world's island, at ground level. An index past the end wraps around, so it is never nil.
function Layout.islandCFrame(index: number): CFrame
	local slot = (index - 1) % Layout.ISLAND_COUNT
	local column, row = slot % 6, slot // 6
	return CFrame.new(Layout.ISLAND_ORIGIN + Vector3.new((column - 2.5) * Layout.ISLAND_SPACING, 0, (row - 0.5) * Layout.ISLAND_SPACING))
end

-- Where players arrive on an island: its middle, facing north.
function Layout.islandSpawn(index: number): CFrame
	local position = Layout.islandCFrame(index) * Vector3.new(0, 3.2, 0)
	return CFrame.lookAt(position, position - Vector3.zAxis)
end

----------------------------------------------------------------------------------------------------
-- Plots (the idle defence game). Every player owns one plot, their base: monsters walk its path from the
-- portal to the base's gate, and cannon towers stand on pads beside the path.
-- Plot space: the base is at the origin end, +Z runs up the plot towards the portal, the ground's top is y = 0.
-- Every base is private: the twelve stand alone, PLOT_SPACING apart in two rows far from each other, from the
-- marketplace and from the islands, so nothing of another base (or of anything else) is ever in view. All
-- twelve face the same way. A player reaches somebody else's base only by invitation (Features/Visit.luau).
----------------------------------------------------------------------------------------------------
Layout.PLOT_COUNT = 12
Layout.PLOT_WIDTH = 110 -- along X, centred on the plot's origin
Layout.PLOT_DEPTH = 150 -- along +Z from the origin
Layout.PLOT_YARD = 16 -- the ground behind the origin (towards -Z), where the owner arrives
Layout.PLOT_SPACING = 2000 -- from one base's origin to the next one's in its row
Layout.PLOT_ROWS = { 4000, -4000 } -- the z of each row's origins: six bases in a row
Layout.PLOT_APART = 1500 -- no two bases, and no base and anything else, are closer than this (the tools check it)
Layout.FALL_HEIGHT = -40 -- a character below this fell off the map: the server puts it back on its base
-- Where a character appears before the game has moved it to its base: a small closed room of its own.
Layout.LOBBY = Vector3.new(0, 0, -2400)
Layout.PATH_WIDTH = 8

-- The path, as points in plot space (x, z). Monsters enter at the first and are through at the last.
local PATH = {
	Vector2.new(0, 145), -- the portal
	Vector2.new(0, 128),
	Vector2.new(-38, 128),
	Vector2.new(-38, 98),
	Vector2.new(38, 98),
	Vector2.new(38, 68),
	Vector2.new(-38, 68),
	Vector2.new(-38, 38),
	Vector2.new(0, 38),
	Vector2.new(0, 14), -- the base's gate
}
Layout.PATH = PATH

-- Cannon pads, in the order the game suggests them (the first is the free starter pad, near the gate).
local PADS = {
	Vector2.new(-14, 26),
	Vector2.new(14, 26),
	Vector2.new(-8, 53),
	Vector2.new(8, 53),
	Vector2.new(-24, 53),
	Vector2.new(24, 53),
	Vector2.new(-8, 83),
	Vector2.new(8, 83),
	Vector2.new(-24, 83),
	Vector2.new(24, 83),
	Vector2.new(-20, 113),
	Vector2.new(4, 113),
	Vector2.new(24, 113),
	Vector2.new(-50, 53),
	Vector2.new(50, 83),
	Vector2.new(-50, 113),
}
Layout.PADS = PADS
Layout.PAD_COUNT = #PADS
Layout.PAD_SIZE = 7 -- a pad is a square this wide

-- Where the path's segments start, measured along the path.
local pathStarts, pathLength = {}, 0
for index = 1, #PATH - 1 do
	pathStarts[index] = pathLength
	pathLength += (PATH[index + 1] - PATH[index]).Magnitude
end
Layout.PATH_LENGTH = pathLength

-- The plot a slot stands on: its origin is the middle of the base's edge of the ground, 14 studs behind the
-- gate (the yard runs on behind it), +Z up the plot. Every base faces the same way. A slot past the end wraps around, so it is never nil.
function Layout.plotCFrame(slot: number): CFrame
	local index = (slot - 1) % Layout.PLOT_COUNT
	local column, row = index % 6, index // 6
	return CFrame.new((column - 2.5) * Layout.PLOT_SPACING, 0, Layout.PLOT_ROWS[row + 1])
end

-- A point of plot space (x, z, and optionally a height) in the world.
function Layout.plotPoint(slot: number, point: Vector2, height: number?): Vector3
	return Layout.plotCFrame(slot) * Vector3.new(point.X, height or 0, point.Y)
end

-- The point `distance` studs along the path, in plot space, and the direction of travel there.
-- Distances before the start or past the end are clamped.
function Layout.pathAt(distance: number): (Vector2, Vector2)
	local d = math.clamp(distance, 0, pathLength)
	local index = #PATH - 1
	for segment = 1, #PATH - 1 do
		if d <= pathStarts[segment] + (PATH[segment + 1] - PATH[segment]).Magnitude then
			index = segment
			break
		end
	end
	local from, to = PATH[index], PATH[index + 1]
	local direction = (to - from).Unit
	return from + direction * (d - pathStarts[index]), direction
end

-- Where a player stands when they arrive on their plot: behind the gate, facing up the plot.
function Layout.plotSpawn(slot: number): CFrame
	local position = Layout.plotPoint(slot, Vector2.new(0, 4), 3)
	return CFrame.lookAt(position, Layout.plotPoint(slot, Vector2.new(0, 40), 3))
end

-- The two teleporters of a base, in plot space: beside where the owner arrives (Layout.plotSpawn), on the
-- plaza behind the gate, clear of the path and of every pad. `worlds` opens the WORLDS window (the way to the
-- islands), `market` leads to the marketplace.
Layout.TELEPORTERS = {
	worlds = Vector2.new(-13, 3),
	market = Vector2.new(13, 3),
}

function Layout.padPosition(slot: number, pad: number): Vector3
	return Layout.plotPoint(slot, PADS[pad])
end

return Layout
