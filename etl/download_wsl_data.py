import json
import urllib.request
from pathlib import Path
import time

PROJECT_ROOT = Path(__file__).resolve().parent.parent

MATCHES_FILE = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "statsbomb"
    / "wsl_2023_24.json"
)

EVENTS_FOLDER = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "statsbomb"
    / "events"
)

LINEUPS_FOLDER = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "statsbomb"
    / "lineups"
)

EVENTS_FOLDER.mkdir(parents=True, exist_ok=True)
LINEUPS_FOLDER.mkdir(parents=True, exist_ok=True)

with open(MATCHES_FILE, "r", encoding="utf-8") as f:
    matches = json.load(f)

match_ids = [match["match_id"] for match in matches]

print(f"Found {len(match_ids)} matches.")

for number, match_id in enumerate(match_ids, start=1):

    event_url = (
        "https://raw.githubusercontent.com/"
        "statsbomb/open-data/master/data/events/"
        f"{match_id}.json"
    )

    lineup_url = (
        "https://raw.githubusercontent.com/"
        "statsbomb/open-data/master/data/lineups/"
        f"{match_id}.json"
    )

    event_file = EVENTS_FOLDER / f"{match_id}.json"
    lineup_file = LINEUPS_FOLDER / f"{match_id}.json"

    print(f"[{number}/{len(match_ids)}] Match {match_id}")

    if not event_file.exists():
        urllib.request.urlretrieve(event_url, event_file)
        print("  Events downloaded")
    else:
        print("  Events already exist")

    if not lineup_file.exists():
        urllib.request.urlretrieve(lineup_url, lineup_file)
        print("  Lineup downloaded")
    else:
        print("  Lineup already exists")

    time.sleep(0.1)

print("Finished.")