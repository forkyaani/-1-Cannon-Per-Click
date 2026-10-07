"""The look of the twelve worlds, for island.py, base.py and creatures.py: `THEMES[world][key]`.

    import os, sys
    sys.path.insert(0, os.path.dirname(__file__))
    from themes import THEMES
    theme = THEMES["Moon"]          # Config.Worlds' names: "Earth", "Moon", "Mars", "Neptune", "The Sun",
                                    # "The Void", "Nebula", "Crystal Belt", "Robot Factory", "Alien Jungle",
                                    # "Black Hole", "The Big Bang"
    box(size, at, theme["stone"])

Plain data: no Blender needed to import it. Colours are hex strings as kit.py takes them. Every world has
the same keys. Earth's values are the constants earth_island.py was built with: change one and the live
Earth island changes. The others follow Config.Worlds (floor, backdrop) and the THEMES of Islands.luau and
Plots.luau, pushed to the chunky, saturated candy look: no dull greys anywhere. The dark worlds (The Void,
Black Hole) are deep saturated colour under a strong glow, never grey or black; the Robot Factory's metal
is blue steel, hazard yellow and orange paint.

What each key is for (a world without the real thing has a stand-in under the same key)
  grass, grass_light, grass_deep, grass_rim
        the ground you walk on: its main colour, the lighter and darker patches on it, and the darker lip
        that hangs over the edge in drips. Moon dust, Mars sand, Neptune snow, the Sun's glowing crust, the
        Void's violet glass, Nebula's pink gas, the Belt's teal crystal dust, the Factory's blue plate with
        a hazard-yellow lip, the Jungle's jade moss, the Black Hole's plum rock with a burning lip, the Big
        Bang's cream-gold light.
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
        dark red ironwood. Neptune: frozen deep-blue timber. The Sun: charred obsidian. The Void: indigo
        void-stone. Nebula: indigo star-metal. Crystal Belt: amethyst. Robot Factory: orange painted steel.
        Alien Jungle: purple vine-wood. Black Hole: dark plum rock. The Big Bang: gold.
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
        "void_shard"   The Void: shards of rock hanging over their stump round a glowing core, or a broken
                       obelisk whose pieces float apart (`leaves` is the glow)
        "gas_cloud"    Nebula: a heap of gas puffs with a ring and newborn stars, or a plume up to a star
        "crystal_cluster"  Crystal Belt: six-sided crystals in the three `leaves` colours out of a chunk
                       of asteroid; the tall one has a belt of small rocks round it
        "factory_stack"    Robot Factory: a bolted tank with a gauge and a pipe, or a striped chimney with
                       a puff of steam (`leaves` is the paint)
        "glow_shroom"  Alien Jungle: a giant mushroom with glowing spots, wide and squat, or tall with a
                       bell cap and hanging lights (`leaves` is the cap)
        "bent_rock"    Black Hole: rock pulled out of shape, a horn bending to a tiny black hole or two
                       claws closing over one (`leaves` is the ring of fire)
        "spark_burst"  The Big Bang: a spark with shards flying out of it, stopped mid-burst, or a beam
                       with rings of them (`leaves` is the shards)
  liquid
        what `water` is: "water" (Earth), "stardust" (Moon: a glowing lilac pool, emissive), "oasis" (Mars:
        turquoise water), "ice" (Neptune: frozen, no ripples, no fall mist), "lava" (The Sun: emissive),
        "rift" (The Void: a glowing magenta tear, shards hanging over it), "gas" (Nebula: glowing teal gas
        with puffs on it), "prism" (Crystal Belt: liquid crystal set hard, crystals growing out of it, no
        mist), "coolant" (Robot Factory: glowing green, out of a pipe), "acid" (Alien Jungle: glowing lime,
        bubbling), "singularity" (Black Hole: a ring of fire round a dark core), "energy" (The Big Bang:
        white-gold). All of the new seven but "prism" are emissive.
  fence
        the rim's fence: "wood_rail" (Earth: posts and two rails), "metal_rail" (Moon: posts with a glowing
        bulb and one rail), "rope_post" (Mars: stone posts and sagging ropes), "ice_post" (Neptune: shards
        with a rail of ice), "basalt_chain" (The Sun: basalt posts with ember tops and chains),
        "rift_post" (The Void: obelisks with a floating gem and a beam of light), "star_rope" (Nebula: posts
        with a star on top and a sagging rope), "crystal_post" (Crystal Belt: stone posts with a gem and a
        rail), "pipe_rail" (Robot Factory: striped bollards and two pipes), "vine_post" (Alien Jungle:
        thorns with a glowing pod and hanging vines), "orbit_post" (Black Hole: posts with a ringed ball and
        a glowing chain), "spark_post" (The Big Bang: gold posts with a spark and a lightning rail)
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
    "The Void": {  # deep violet-indigo under a black-violet sky, lit magenta by the rift
        "grass": "5632B4", "grass_light": "6C46D2", "grass_deep": "44249A", "grass_rim": "8A2ACC",
        "dirt": "4A22A0", "dirt_dark": "361880",
        "under": "2A1270", "under_dark": "1E0C56", "under_light": "3C1C96",
        "rock": "5A34B8", "rock_dark": "42249A", "rock_light": "7A52DA",
        "sand": "7A5AE8", "sand_dark": "5A3CC8", "cobble": "9C7CFF",
        "stone": "6A48D0", "stone_dark": "4E30AE", "stone_pale": "9274F0",
        "wood": "2E1470", "wood_light": "4A28A0", "wood_dark": "200C54",
        "water": "FF3CC8", "water_light": "FFA8F0",
        "leaves": ("E05CFF", "FF3C8C", "78DCFF"),
        "petals": ("FF3C8C", "F6C2FF", "78DCFF", "E05CFF", "A050FF"),
        "accent": "E05CFF", "accent_pale": "F6C2FF",
        "sky_top": "0C0618", "sky_horizon": "3A1A7A",
        "tree": "void_shard", "liquid": "rift", "fence": "rift_post",
    },
    "Nebula": {  # pink gas on purple, teal rock, a pink dawn
        "grass": "F08AD8", "grass_light": "FFAEE8", "grass_deep": "E070C8", "grass_rim": "B04CC0",
        "dirt": "9A58D8", "dirt_dark": "7444C0",
        "under": "4E3AA8", "under_dark": "3A2A8A", "under_light": "6A54C4",
        "rock": "5AD8D0", "rock_dark": "38B4B8", "rock_light": "9AF0E4",
        "sand": "FFE4F8", "sand_dark": "F4BCE8", "cobble": "FFF2FC",
        "stone": "D8C8FF", "stone_dark": "B4A0F0", "stone_pale": "F0E8FF",
        "wood": "6A54C4", "wood_light": "9A84E8", "wood_dark": "4A389A",
        "water": "5CE8E0", "water_light": "C8FFF8",
        "leaves": ("FF9CE0", "6CE0E8", "B49CFF"),
        "petals": ("FF7AD0", "FFFFFF", "FFE27A", "6CE0E8", "B49CFF"),
        "accent": "78F0FF", "accent_pale": "D8FBFF",
        "sky_top": "5A3AB8", "sky_horizon": "F08ACC",
        "tree": "gas_cloud", "liquid": "gas", "fence": "star_rope",
    },
    "Crystal Belt": {  # teal crystal dust on navy rock, crystals in violet, pink and gold, a night sky
        "grass": "40BEB8", "grass_light": "62D8CE", "grass_deep": "2CA4A4", "grass_rim": "1C7C94",
        "dirt": "2A6CA8", "dirt_dark": "1E4E8C",
        "under": "1A3A78", "under_dark": "122A5C", "under_light": "2A54A0",
        "rock": "6A6CC0", "rock_dark": "4C4E9E", "rock_light": "9092DC",
        "sand": "E4FFF8", "sand_dark": "A4E8DC", "cobble": "F2FFFC",
        "stone": "B8A8F0", "stone_dark": "9484D8", "stone_pale": "DCD0FF",
        "wood": "5A3CB0", "wood_light": "8A68E0", "wood_dark": "3E2888",
        "water": "C08CFF", "water_light": "ECD8FF",
        "leaves": ("B46CFF", "FF7AD0", "FFD24A"),
        "petals": ("FF7AD0", "FFFFFF", "FFD24A", "8CF0E6", "B46CFF"),
        "accent": "C08CFF", "accent_pale": "ECD8FF",
        "sky_top": "101E4A", "sky_horizon": "2E6C9C",
        "tree": "crystal_cluster", "liquid": "prism", "fence": "crystal_post",
    },
    "Robot Factory": {  # blue steel plate with a hazard-yellow lip, orange paint, green coolant, a yellow sky
        "grass": "5C8CEA", "grass_light": "7CA8F8", "grass_deep": "4878D6", "grass_rim": "FFC21A",
        "dirt": "E8862A", "dirt_dark": "C2621E",
        "under": "3E4C8C", "under_dark": "2C3870", "under_light": "5668AC",
        "rock": "5668AC", "rock_dark": "3E4C8C", "rock_light": "7C8ED0",
        "sand": "D4E0F8", "sand_dark": "FFC21A", "cobble": "EEF4FF",
        "stone": "C4D2F0", "stone_dark": "8C9CCC", "stone_pale": "E8EEFC",
        "wood": "E8582A", "wood_light": "FF8A3C", "wood_dark": "A83A20",
        "water": "50FFAA", "water_light": "C8FFE4",
        "leaves": ("FFC21A", "FF6A2A", "4AD8FF"),
        "petals": ("FFC21A", "FFFFFF", "FF6A2A", "4AD8FF", "50FFAA"),
        "accent": "50FFAA", "accent_pale": "C8FFE4",
        "sky_top": "F0A82A", "sky_horizon": "FFE48A",
        "tree": "factory_stack", "liquid": "coolant", "fence": "pipe_rail",
    },
    "Alien Jungle": {  # jade moss on purple soil, pink and purple glowing caps, lime acid, a lime sky
        "grass": "1FA882", "grass_light": "38C898", "grass_deep": "18906E", "grass_rim": "0E6A5C",
        "dirt": "7A3CA8", "dirt_dark": "5A2A88",
        "under": "3E2470", "under_dark": "2C1858", "under_light": "56348E",
        "rock": "7E58C0", "rock_dark": "5E3EA0", "rock_light": "A480E0",
        "sand": "D8F28A", "sand_dark": "A8D45A", "cobble": "ECFAB8",
        "stone": "CFEFC0", "stone_dark": "9CCF98", "stone_pale": "EAFBE0",
        "wood": "8A3CA0", "wood_light": "C068D0", "wood_dark": "5E2478",
        "water": "B4FF2A", "water_light": "F0FF9A",
        "leaves": ("FF5AB4", "A85CFF", "FFB03C"),
        "petals": ("FF5AB4", "FFF3C8", "FFB03C", "A85CFF", "B4FF2A"),
        "accent": "FF6AC8", "accent_pale": "FFC8EC",
        "sky_top": "2E9E7A", "sky_horizon": "C8F06A",
        "tree": "glow_shroom", "liquid": "acid", "fence": "vine_post",
    },
    "Black Hole": {  # plum rock with a burning orange lip under a crimson-black sky, rings of fire
        "grass": "7A2278", "grass_light": "92308E", "grass_deep": "641A64", "grass_rim": "FF6A1E",
        "dirt": "8A1E3C", "dirt_dark": "641432",
        "under": "4A1248", "under_dark": "360A3A", "under_light": "681E62",
        "rock": "541A52", "rock_dark": "3E1240", "rock_light": "702A6C",
        "sand": "FFB46A", "sand_dark": "F0782E", "cobble": "FFD49A",
        "stone": "7A2E66", "stone_dark": "5A1E4C", "stone_pale": "A04A86",
        "wood": "481050", "wood_light": "6C2478", "wood_dark": "340A3C",
        "water": "FF6A1E", "water_light": "FFD24A",
        "leaves": ("FF8A1E", "FF3C8C", "FFD24A"),
        "petals": ("FF8A1E", "FFE8C0", "FF3C8C", "FFD24A", "5ADCE6"),
        "accent": "FF8A28", "accent_pale": "FFD8A0",
        "sky_top": "1A0616", "sky_horizon": "A01C40",
        "tree": "bent_rock", "liquid": "singularity", "fence": "orbit_post",
    },
    "The Big Bang": {  # white paving on pale gold, violet underneath, shards in red, blue and purple, a pink dawn
        "grass": "FFE080", "grass_light": "FFF2BC", "grass_deep": "FFCE58", "grass_rim": "FF9E2E",
        "dirt": "FFB84A", "dirt_dark": "F0902E",
        "under": "B45CE0", "under_dark": "8A3CC0", "under_light": "D488F4",
        "rock": "FFF8E8", "rock_dark": "FFD890", "rock_light": "FFFFFF",
        "sand": "FFFFFF", "sand_dark": "FFD24A", "cobble": "FFFBEA",
        "stone": "FFF6E0", "stone_dark": "F4D898", "stone_pale": "FFFFFF",
        "wood": "E8A020", "wood_light": "FFD24A", "wood_dark": "B87410",
        "water": "FFC83C", "water_light": "FFFFFF",
        "leaves": ("FF4A5A", "3C9CFF", "B45CFF"),
        "petals": ("FF4A5A", "FFFFFF", "3C9CFF", "B45CFF", "28C8B4"),
        "accent": "FFD83A", "accent_pale": "FFFBD0",
        "sky_top": "FF9EC4", "sky_horizon": "FFF4D8",
        "tree": "spark_burst", "liquid": "energy", "fence": "spark_post",
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
