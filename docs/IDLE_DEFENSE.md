# Idle defence pivot: one-page design

Status: approved by Yaani on 2 Oct 2026 with three changes (third person, no tapping, separate towers).
Being built. The technical contract is `docs/DEFENSE_SPEC.md`.

## The game in one line

Monsters march down a path at your base. You walk around your plot, buy cannon pads beside the path and build
cannon towers on them. The towers shoot on their own. Beat a world's boss to open the next world.

## Core loop

1. Monsters walk the path toward your gate. Each one that gets through costs lives; at zero the level is lost.
2. Towers fire by themselves, also while you are in the marketplace.
3. Kills pay coins. Coins buy more pads, new kinds of tower and tower upgrades.
4. Eggs hatch mini cannons. They follow you, multiply all tower damage and shoot monsters near you.
5. Level 50's boss opens the next world: new look, new monsters, new eggs. Nothing resets.

## Yaani's decisions

| Question | Decision |
|---|---|
| Camera | Third person, walking around your own plot. Tapping to fire is removed |
| What stands on pads | Separate buyable towers. Mini cannons stay as pets |
| Rebirth | Rely on it less: a longer, harder game where levels have to be ground past. No rebirth in this version |

## What changes

| Before | After |
|---|---|
| Fixed camera on one lane, tap to fire a big cannon | Walk around your plot; nothing to tap |
| Mini cannons were the only extra guns | Towers on pads are the guns: Cannon, Gatling, Mortar, Sniper, Frost and more, each upgradable |
| Equip slots | 16 pads, bought with coins one at a time, each dearer than the last |
| Monsters heal, wave on a timer | Monsters walk; leaks cost lives |
| Rebirth resets you for a multiplier | No rebirth. 12 worlds of 50 levels, power carries over |
| "+1 Cannon Power Per Click" | Decided 4 Oct: the game is called "+1 Cannon Per Click" (`Config.GameName`) |

## What stays

Eggs, fusing, Secrets and Huges, crates and the opening animation, the loot viewer, trading, ammo, powerups,
the backpack, the story, the marketplace, the 12 worlds and their monsters, the Candy Arcade UI kit.

## What goes or gets replaced

- The big cannon, tapping, the combo. Mega Blast becomes a charged ability; the Power Orb becomes a pickup on the plot.
- Rebirth, the rebirth leaderboard (becomes "furthest level") and the rebirth quests in the story.
- The Auto Rebirth pass becomes another pass (offline earnings is the candidate).
- Current saves are wiped (only test saves exist).

## Build plan (about a week)

| Day | Work |
|---|---|
| 1-2 | New server core (levels, towers, lives), the plots, the client: walking, monsters, tower shots, tower window |
| 3 | The existing features adapted to towers: Huge, ammo, powerups, abilities, story, crates |
| 4-5 | Balance from scratch with a simulator: long, with walls that need grinding. Offline earnings |
| 6 | Phone check, new name and texts, passes |
| 7 | Studio testing, fixes, publish |

## Risks

- **A week with the live game unchanged.** The concept has to stay locked until this ships.
- **Balance is redone from zero.** It was broken anyway.
- **Performance.** Twelve plots of walking monsters; the monsters are drawn by each player's own device to keep it light.
