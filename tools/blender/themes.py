"""The look of the five launch worlds, for island.py, base.py and creatures.py: `THEMES[world][key]`.

    import os, sys
    sys.path.insert(0, os.path.dirname(__file__))
    from themes import THEMES
    theme = THEMES["Moon"]          # "Earth", "Moon", "Mars", "Neptune", "The Sun" (Config.Worlds' names)
    box(size, at, theme["stone"])

Plain data: no Blender needed to import it. Colours are hex strings as kit.py takes them. Every world has
the same keys. Earth's values are the constants earth_island.py was built with: change one and the live
Earth island changes. The others follow Config.Worlds (floor, backdrop) and the THEMES of Islands.luau and
Plots.luau, pushed to the chunky, saturated candy look: no dull greys anywhere.

What each key is for (a world without the real thing has a stand-in under the same key)
  grass, grass_light, grass_deep, grass_rim
        the ground you walk on: its main colour, the lighter and darker patches on it, and the darker lip
        that hangs over the edge in drips. Moon dust, Mars sand, Neptune snow, the Sun's glowing crust.
  dirt, dirt_dark
        the two bands under the ground's lip, on the island's side.
  under, under_dark, under_light
        the rock that tapers to a point under an island, and its hanging spikes.
  rock, rock_dark, rock_light
        boulders, stones in the dirt wall, floating rocks, cliffs.
  sand, sand_dark, cobble
        paving: the plaza and the paths, the darker band round them, single paving stones.
  stone, stone_dark, stone_pale
        what is built: pedestals, steps, arches, lamp feet, walls.
  wood, wood_light, wood_dark
        timber and its stand-in: fences, counters, trunks, bridges, crates. Moon: brushed blue metal. Mars:
        dark red ironwood. Neptune: frozen deep-blue timber. The Sun: charred obsidian.
  water, water_light
        the liquid in ponds and streams, and the lighter streaks and middles on it. See `liquid`.
  leaves
        three tones for what grows: tree tops and bushes on Earth; elsewhere the caps, crystals or glow of
        that world's `tree`. Use the three as Earth does: [0] main, [1] deeper, [2] lighter.
  petals
        five bright colours for the small dressing: flowers, gems, pebbles, bunting.
  accent, accent_pale
        the world's glow, for Neon: the portal's sheet and runes, crystals, lamps. Pale is its highlight.
  sky_top, sky_horizon
        the photos' sky, straight up and at the horizon: kit.sky_ramp(theme["sky_top"], theme["sky_horizon"]).
        (Earth's photos use kit.EARTH_SKY, the hand-made ramp these two are taken from.)
  tree
        the kind of tall prop that stands where Earth has trees:
        "round_tall"   Earth: a fat trunk with balls of leaves, round or stacked like a fir
        "crater_rock"  Moon: a boulder with a crater bowl in it and crystals of `leaves` growing out
        "mesa_spire"   Mars: a flat-topped spire of stacked rock layers in the `leaves` tones
        "ice_spike"    Neptune: a cluster of leaning ice shards
        "lava_spire"   The Sun: a basalt spire with glowing cracks and a molten tip (`leaves`, emissive)
  liquid
        what `water` is: "water" (Earth), "stardust" (Moon: a glowing lilac pool, emissive), "oasis" (Mars:
        turquoise water), "ice" (Neptune: frozen, no ripples, no fall mist), "lava" (The Sun: emissive)
  fence
        the rim's fence: "wood_rail" (Earth: posts and two rails), "metal_rail" (Moon: posts with a glowing
        bulb and one rail), "rope_post" (Mars: stone posts and sagging ropes), "ice_post" (Neptune: shards
        with a rail of ice), "basalt_chain" (The Sun: basalt posts with ember tops and chains)
"""

THEMES = {
    "Earth": {
        "grass": "6FD046", "grass_light": "92E35A", "grass_deep": "58BE3E", "grass_rim": "389A45",
        "dirt": "C98B4D", "dirt_dark": "9C6436",
        "under": "7C75A3", "under_dark": "5F5888", "under_light": "958EB6",
        "rock": "9A93B5", "rock_dark": "756E98", "rock_light": "B9B3CF",
        "sand": "F6DFA6", "sand_dark": "E3C385", "cobble": "FFF1CC",
        "stone": "DCD6CC", "stone_dark": "B9B2A8", "stone_pale": "F4EFE6",
        "wood": "B9783F", "wood_light": "E3B06B", "wood_dark": "8A5A2B",
        "water": "3FBDF5", "water_light": "A8E8FF",
        "leaves": ("4FC44A", "2FA85A", "8FD93E"),
        "petals": ("FF7AB8", "FFFFFF", "FFD83A", "FF5A5A", "B58CFF"),
        "accent": "8E6BFF", "accent_pale": "C7B5FF",
        "sky_top": "3F8FE0", "sky_horizon": "C4E8FF",
        "tree": "round_tall", "liquid": "water", "fence": "wood_rail",
    },
    "Moon": {  # lilac dust and silver rock under a night sky
        "grass": "C9BCF2", "grass_light": "DFD6FB", "grass_deep": "B2A2E8", "grass_rim": "8B78D0",
        "dirt": "A596D8", "dirt_dark": "8170BE",
        "under": "6C60A8", "under_dark": "52488C", "under_light": "8A7EC2",
        "rock": "B9B5DA", "rock_dark": "938EC0", "rock_light": "DAD7EE",
        "sand": "ECE8FB", "sand_dark": "CEC6EE", "cobble": "F8F6FF",
        "stone": "D9D7EC", "stone_dark": "B2AED2", "stone_pale": "F2F1FB",
        "wood": "8FA0DA", "wood_light": "BDC9F2", "wood_dark": "6272B6",
        "water": "B9A6FF", "water_light": "E8E0FF",
        "leaves": ("7FD8FF", "5CB6F2", "B8ECFF"),
        "petals": ("FF9BE0", "FFFFFF", "FFE27A", "7FD8FF", "B58CFF"),
        "accent": "7FB4FF", "accent_pale": "D2E4FF",
        "sky_top": "17153F", "sky_horizon": "4D4296",
        "tree": "crater_rock", "liquid": "stardust", "fence": "metal_rail",
    },
    "Mars": {  # warm orange-red sand and layered rock under a peach evening
        "grass": "F0803C", "grass_light": "FF9F56", "grass_deep": "DB692E", "grass_rim": "B84A26",
        "dirt": "C9552E", "dirt_dark": "9E3B24",
        "under": "8E3A3C", "under_dark": "6E2A34", "under_light": "AC5048",
        "rock": "D9663A", "rock_dark": "B04A2C", "rock_light": "F2905A",
        "sand": "FFD9A0", "sand_dark": "F0B878", "cobble": "FFE9C4",
        "stone": "F2C9A0", "stone_dark": "D6A27A", "stone_pale": "FFE6CC",
        "wood": "8A3B40", "wood_light": "BA5A5C", "wood_dark": "662A32",
        "water": "35D6C4", "water_light": "A6F5E6",
        "leaves": ("FF7A3D", "E5532D", "FFB45A"),
        "petals": ("FFD25A", "FFF3D6", "5FD08A", "FF5A5A", "35D6C4"),
        "accent": "FF783C", "accent_pale": "FFCBA2",
        "sky_top": "F0884E", "sky_horizon": "FFD9A8",
        "tree": "mesa_spire", "liquid": "oasis", "fence": "rope_post",
    },
    "Neptune": {  # icy blue-teal: snow on top, deep blue ice underneath
        "grass": "BDEBFF", "grass_light": "E2F7FF", "grass_deep": "93D8F8", "grass_rim": "4FA8E8",
        "dirt": "5FB4EE", "dirt_dark": "3F8ED8",
        "under": "3A6FCC", "under_dark": "2A52A8", "under_light": "5C90E0",
        "rock": "7FC4F2", "rock_dark": "559EDC", "rock_light": "B4E2FB",
        "sand": "E8FAFF", "sand_dark": "BFE9F8", "cobble": "F6FDFF",
        "stone": "D2ECF8", "stone_dark": "A6D2EA", "stone_pale": "F0FAFF",
        "wood": "4A7FD0", "wood_light": "7FB0EE", "wood_dark": "30589E",
        "water": "6FE0F2", "water_light": "C8F8FF",
        "leaves": ("7FE8F0", "4FC8E0", "C6F8FF"),
        "petals": ("FFFFFF", "9BF0FF", "B58CFF", "5AE1FF", "FF9BE0"),
        "accent": "6EE6FF", "accent_pale": "D0F8FF",
        "sky_top": "3264C8", "sky_horizon": "A8DCFF",
        "tree": "ice_spike", "liquid": "ice", "fence": "ice_post",
    },
    "The Sun": {  # a gold-orange crust on dark basalt, lava in the cracks
        "grass": "FF9A2E", "grass_light": "FFC04A", "grass_deep": "F27A1E", "grass_rim": "D9461A",
        "dirt": "8A3A2C", "dirt_dark": "5E2A2C",
        "under": "3F2632", "under_dark": "2C1A28", "under_light": "5A3542",
        "rock": "4A2C3A", "rock_dark": "33202E", "rock_light": "6A4052",
        "sand": "FFE08A", "sand_dark": "F5BE5A", "cobble": "FFF0B8",
        "stone": "5C3848", "stone_dark": "432836", "stone_pale": "7A4E5E",
        "wood": "3A2230", "wood_light": "5A3646", "wood_dark": "26141E",
        "water": "FF5A1A", "water_light": "FFD23A",
        "leaves": ("FFB52E", "FF6A1F", "FFE56A"),
        "petals": ("FFE56A", "FFFFFF", "FF8A1F", "FF4D4D", "FFC61A"),
        "accent": "FFC83C", "accent_pale": "FFF0A8",
        "sky_top": "FF7A1E", "sky_horizon": "FFE27A",
        "tree": "lava_spire", "liquid": "lava", "fence": "basalt_chain",
    },
}

if __name__ == "__main__":  # python3 tools/blender/themes.py: checks every world has every key and every colour is a hex code
    keys = set(THEMES["Earth"])
    for world, theme in THEMES.items():
        assert set(theme) == keys, (world, set(theme) ^ keys)
        for key, value in theme.items():
            if key in ("tree", "liquid", "fence"):
                continue
            for colour in (value if isinstance(value, tuple) else (value,)):
                int(colour, 16)
                assert len(colour) == 6 and colour == colour.upper(), (world, key, colour)
    print(f"{len(THEMES)} worlds, {len(keys)} keys each: fine")
