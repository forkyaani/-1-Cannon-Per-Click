#!/usr/bin/env python3
"""Posts Cannon Tower Defense's public Roblox numbers to a Discord webhook.

Run every few minutes (launchd: tools/alerts/install.sh). Each run reads Roblox's public games API and posts:
  - an alert when the player count reaches a new peak or a milestone, and when visits, favourites or likes
    reach a milestone;
  - an alert when the game is updated (a publish) or a dislike arrives;
  - a stats post every REPORT_EVERY seconds, with the change since the last one;
  - a summary of the day before, on the first run of a new day.

The webhook URL is read from $DISCORD_WEBHOOK_URL or ~/.ctd-alerts/webhook_url (never from the repo).
State is kept in ~/.ctd-alerts/state.json. `--dry-run` prints the posts instead of sending them;
`--report` forces a stats post.
"""
import datetime
import json
import os
import sys
import time
import urllib.request

UNIVERSE = 10769534537
PLACE = 80923792816716
GAME_URL = f"https://www.roblox.com/games/{PLACE}"
REPORT_EVERY = 3600
CCU_MILESTONES = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
VISIT_MILESTONES = [250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000, 250000, 500000, 1000000]
FAVOURITE_MILESTONES = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
LIKE_MILESTONES = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

HOME = os.path.expanduser("~/.ctd-alerts")
STATE = os.path.join(HOME, "state.json")
GREEN, GOLD, BLUE, RED = 0x57F287, 0xFEE75C, 0x5865F2, 0xED4245


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "ctd-alerts/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def fetch():
    game = get(f"https://games.roblox.com/v1/games?universeIds={UNIVERSE}")["data"][0]
    votes = get(f"https://games.roblox.com/v1/games/votes?universeIds={UNIVERSE}")["data"][0]
    return {
        "playing": game["playing"],
        "visits": game["visits"],
        "favourites": game["favoritedCount"],
        "likes": votes["upVotes"],
        "dislikes": votes["downVotes"],
        "updated": game["updated"],
        "name": game["name"],
    }


def webhook_url():
    url = os.environ.get("DISCORD_WEBHOOK_URL")
    if not url:
        with open(os.path.join(HOME, "webhook_url")) as file:
            url = file.read().strip()
    return url


def post(embeds, dry):
    if dry:
        print(json.dumps(embeds, indent=2, ensure_ascii=False))
        return
    body = json.dumps({"username": "CTD Alerts", "embeds": embeds}).encode()
    request = urllib.request.Request(
        webhook_url(), data=body, headers={"Content-Type": "application/json", "User-Agent": "ctd-alerts/1.0"}
    )
    urllib.request.urlopen(request, timeout=20).close()


def signed(n):
    return f"+{n:,}" if n >= 0 else f"{n:,}"


def crossed(milestones, before, now):
    """The highest milestone passed between two readings, or None."""
    hit = [m for m in milestones if before < m <= now]
    return hit[-1] if hit else None


def rating(now):
    votes = now["likes"] + now["dislikes"]
    return f"{100 * now['likes'] / votes:.0f}%" if votes else "none yet"


def stats_embed(title, now, since, colour, extra=None):
    fields = [
        ("Playing now", f"{now['playing']:,}"),
        ("Visits", f"{now['visits']:,} ({signed(now['visits'] - since['visits'])})"),
        ("Favourites", f"{now['favourites']:,} ({signed(now['favourites'] - since['favourites'])})"),
        ("Likes", f"{now['likes']:,} ({signed(now['likes'] - since['likes'])})"),
        ("Dislikes", f"{now['dislikes']:,} ({signed(now['dislikes'] - since['dislikes'])})"),
        ("Rating", rating(now)),
    ] + (extra or [])
    return {
        "title": title,
        "url": GAME_URL,
        "color": colour,
        "fields": [{"name": name, "value": value, "inline": True} for name, value in fields],
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }


def alert(text, colour):
    return {"description": text, "color": colour}


def main():
    dry = "--dry-run" in sys.argv
    os.makedirs(HOME, exist_ok=True)
    now = fetch()
    stamp = time.time()
    today = datetime.date.today().isoformat()

    try:
        with open(STATE) as file:
            state = json.load(file)
    except (OSError, ValueError):
        state = None

    if state is None:
        state = {
            "last": now,
            "report": now,
            "report_at": stamp,
            "peak": now["playing"],
            "day": today,
            "day_start": now,
            "day_peak": now["playing"],
        }
        embeds = [stats_embed(f"{now['name']}: alerts are on", now, now, BLUE, [("All-time peak seen", f"{state['peak']:,}")])]
    else:
        last = state["last"]
        embeds = []

        # The day before, once, on the first run of a new day.
        if state["day"] != today:
            embeds.append(
                stats_embed(
                    f"Yesterday ({state['day']})", now, state["day_start"], BLUE, [("Peak players", f"{state['day_peak']:,}")]
                )
            )
            state.update(day=today, day_start=now, day_peak=now["playing"])
        state["day_peak"] = max(state["day_peak"], now["playing"])

        milestone = crossed(CCU_MILESTONES, state["peak"], now["playing"])
        if milestone:
            embeds.append(alert(f"🚀 **{milestone:,} players at once!** {now['playing']:,} are playing now.", GOLD))
        elif now["playing"] > state["peak"]:
            embeds.append(alert(f"📈 **New player peak: {now['playing']:,}** (was {state['peak']:,}).", GREEN))
        state["peak"] = max(state["peak"], now["playing"])

        for key, milestones, text in (
            ("visits", VISIT_MILESTONES, "🎉 **{:,} visits!**"),
            ("favourites", FAVOURITE_MILESTONES, "⭐ **{:,} favourites!**"),
            ("likes", LIKE_MILESTONES, "👍 **{:,} likes!**"),
        ):
            milestone = crossed(milestones, last[key], now[key])
            if milestone:
                embeds.append(alert(text.format(milestone), GOLD))

        if now["dislikes"] > last["dislikes"]:
            embeds.append(alert(f"👎 New dislike: {now['dislikes']:,} in all, rating {rating(now)}.", RED))
        if now["updated"] != last["updated"]:
            embeds.append(alert("🛠️ The game was updated on Roblox (a publish or a settings change).", BLUE))

        if "--report" in sys.argv or stamp - state["report_at"] >= REPORT_EVERY:
            embeds.append(
                stats_embed(
                    "Hourly stats",
                    now,
                    state["report"],
                    BLUE,
                    [("Peak today", f"{state['day_peak']:,}"), ("All-time peak seen", f"{state['peak']:,}")],
                )
            )
            if not dry:
                state.update(report=now, report_at=stamp)
        state["last"] = now

    if embeds:
        post(embeds[:10], dry)
    if not dry:
        with open(STATE, "w") as file:
            json.dump(state, file)


if __name__ == "__main__":
    main()
