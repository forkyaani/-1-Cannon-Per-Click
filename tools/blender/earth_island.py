"""The Earth island under its old name: blender --background --python tools/blender/earth_island.py -- <output folder> [draft] [clutter]
runs island.py for Earth (tools/blender/island.py -- Earth <output folder> ...), which makes the same model."""
import os, runpy, sys
sys.argv[sys.argv.index("--") + 1:sys.argv.index("--") + 1] = ["Earth"]; runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "island.py"), run_name="__main__")
