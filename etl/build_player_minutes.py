import json
import csv
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

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

OUTPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "player_minutes_wsl_2023_24.csv"
)

fieldnames = [
    "match_id",
    "team_id",
    "player_id",
    "player_name",
    "started",
    "starting_position_id",
    "starting_position_name",
    "on_second",
    "off_second",
    "minutes_played",
]

rows = []

event_files = sorted(EVENTS_FOLDER.glob("*.json"))

print(f"Found {len(event_files)} matches.")

for file_number, event_file in enumerate(event_files, start=1):

    match_id = int(event_file.stem)

    with open(event_file, "r", encoding="utf-8") as f:
        events = json.load(f)

    # ---------------------------------------
    # Player-name lookup from lineup file
    # ---------------------------------------

    lineup_file = LINEUPS_FOLDER / f"{match_id}.json"

    player_names = {}

    if lineup_file.exists():

        with open(lineup_file, "r", encoding="utf-8") as f:
            teams = json.load(f)

        for team in teams:

            for player in team.get("lineup", []):

                player_names[player["player_id"]] = (
                    player.get("player_name")
                )

    # ---------------------------------------
    # Find actual end of match
    # ---------------------------------------

    match_end_seconds = max(
        event.get("minute", 0) * 60
        + event.get("second", 0)
        for event in events
    )

    players = {}

    # ---------------------------------------
    # Starting XI
    # ---------------------------------------

    for event in events:

        if event.get("type", {}).get("name") != "Starting XI":
            continue

        team_id = event.get("team", {}).get("id")

        tactics = event.get("tactics", {})

        for starter in tactics.get("lineup", []):

            player = starter.get("player", {})
            position = starter.get("position", {})

            player_id = player.get("id")

            players[player_id] = {
                "match_id": match_id,
                "team_id": team_id,
                "player_id": player_id,
                "player_name":
                    player_names.get(
                        player_id,
                        player.get("name")
                    ),
                "started": True,
                "starting_position_id":
                    position.get("id"),
                "starting_position_name":
                    position.get("name"),
                "on_second": 0,
                "off_second": match_end_seconds,
            }

    # ---------------------------------------
    # Substitutions
    # ---------------------------------------

    for event in events:

        if event.get("type", {}).get("name") != "Substitution":
            continue

        event_time = (
            event.get("minute", 0) * 60
            + event.get("second", 0)
        )

        team_id = event.get("team", {}).get("id")

        player_off = event.get("player", {})
        player_off_id = player_off.get("id")

        substitution = event.get("substitution", {})

        replacement = substitution.get("replacement", {})
        replacement_id = replacement.get("id")

        # Player leaving pitch
        if player_off_id in players:

            players[player_off_id]["off_second"] = event_time

        # Player entering pitch
        if replacement_id is not None:

            players[replacement_id] = {
                "match_id": match_id,
                "team_id": team_id,
                "player_id": replacement_id,
                "player_name":
                    player_names.get(
                        replacement_id,
                        replacement.get("name")
                    ),
                "started": False,
                "starting_position_id": None,
                "starting_position_name": None,
                "on_second": event_time,
                "off_second": match_end_seconds,
            }

    # ---------------------------------------
    # Red cards / second yellows
    # ---------------------------------------

    for event in events:

        card_name = None

        foul = event.get("foul_committed", {})
        bad_behaviour = event.get("bad_behaviour", {})

        if foul.get("card"):
            card_name = foul["card"].get("name")

        elif bad_behaviour.get("card"):
            card_name = bad_behaviour["card"].get("name")

        if card_name not in (
            "Red Card",
            "Second Yellow"
        ):
            continue

        player_id = event.get("player", {}).get("id")

        event_time = (
            event.get("minute", 0) * 60
            + event.get("second", 0)
        )

        if player_id in players:
            players[player_id]["off_second"] = event_time

    # ---------------------------------------
    # Calculate minutes
    # ---------------------------------------

    for player in players.values():

        seconds_played = (
            player["off_second"]
            - player["on_second"]
        )

        # Defensive safety check
        seconds_played = max(seconds_played, 0)

        player["minutes_played"] = round(
            seconds_played / 60,
            2
        )

        rows.append(player)

    print(
        f"[{file_number}/{len(event_files)}] "
        f"Match {match_id}: "
        f"{len(players)} players used"
    )

# ---------------------------------------
# Write CSV
# ---------------------------------------

with open(
    OUTPUT_FILE,
    "w",
    newline="",
    encoding="utf-8"
) as f:

    writer = csv.DictWriter(
        f,
        fieldnames=fieldnames
    )

    writer.writeheader()
    writer.writerows(rows)

print()
print(f"Created: {OUTPUT_FILE}")
print(f"Player-match appearances written: {len(rows)}")