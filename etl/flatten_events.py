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

OUTPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "events_wsl_2023_24.csv"
)

fieldnames = [
    "event_id",
    "match_id",
    "event_index",
    "period",
    "minute",
    "second",

    "possession",
    "possession_team_id",

    "team_id",
    "player_id",
    "position_id",

    "event_type",
    "play_pattern",

    "x",
    "y",
    "end_x",
    "end_y",

    "under_pressure",
    "counterpress",

    "pass_recipient_id",
    "pass_length",
    "pass_angle",
    "pass_height",
    "pass_outcome",
    "pass_type",
    "pass_cross",
    "pass_cut_back",
    "pass_shot_assist",
    "pass_goal_assist",
    "assisted_shot_id",

    "shot_xg",
    "shot_outcome",
    "shot_body_part",
    "shot_technique",

    "dribble_outcome",
    "duel_type",
]

event_files = sorted(EVENTS_FOLDER.glob("*.json"))

print(f"Found {len(event_files)} event files.")

total_rows = 0

with open(
    OUTPUT_FILE,
    "w",
    newline="",
    encoding="utf-8"
) as output:

    writer = csv.DictWriter(
        output,
        fieldnames=fieldnames
    )

    writer.writeheader()

    for file_number, event_file in enumerate(event_files, start=1):

        match_id = int(event_file.stem)

        with open(event_file, "r", encoding="utf-8") as f:
            events = json.load(f)

        match_rows = 0

        for event in events:

            location = event.get("location") or [None, None]

            pass_data = event.get("pass", {})
            carry_data = event.get("carry", {})
            shot_data = event.get("shot", {})
            dribble_data = event.get("dribble", {})
            duel_data = event.get("duel", {})

            end_x = None
            end_y = None

            if pass_data.get("end_location"):
                end_x = pass_data["end_location"][0]
                end_y = pass_data["end_location"][1]

            elif carry_data.get("end_location"):
                end_x = carry_data["end_location"][0]
                end_y = carry_data["end_location"][1]

            row = {
                "event_id": event.get("id"),
                "match_id": match_id,
                "event_index": event.get("index"),
                "period": event.get("period"),
                "minute": event.get("minute"),
                "second": event.get("second"),

                "possession": event.get("possession"),
                "possession_team_id":
                    event.get("possession_team", {}).get("id"),

                "team_id":
                    event.get("team", {}).get("id"),

                "player_id":
                    event.get("player", {}).get("id"),

                "position_id":
                    event.get("position", {}).get("id"),

                "event_type":
                    event.get("type", {}).get("name"),

                "play_pattern":
                    event.get("play_pattern", {}).get("name"),

                "x":
                    location[0] if len(location) > 0 else None,

                "y":
                    location[1] if len(location) > 1 else None,

                "end_x": end_x,
                "end_y": end_y,

                "under_pressure":
                    event.get("under_pressure", False),

                "counterpress":
                    event.get("counterpress", False),

                "pass_recipient_id":
                    pass_data.get("recipient", {}).get("id"),

                "pass_length":
                    pass_data.get("length"),

                "pass_angle":
                    pass_data.get("angle"),

                "pass_height":
                    pass_data.get("height", {}).get("name"),

                "pass_outcome":
                    pass_data.get("outcome", {}).get("name"),

                "pass_type":
                    pass_data.get("type", {}).get("name"),

                "pass_cross":
                    pass_data.get("cross", False),

                "pass_cut_back":
                    pass_data.get("cut_back", False),

                "pass_shot_assist":
                    pass_data.get("shot_assist", False),

                "pass_goal_assist":
                    pass_data.get("goal_assist", False),

                "assisted_shot_id":
                    pass_data.get("assisted_shot_id"),

                "shot_xg":
                    shot_data.get("statsbomb_xg"),

                "shot_outcome":
                    shot_data.get("outcome", {}).get("name"),

                "shot_body_part":
                    shot_data.get("body_part", {}).get("name"),

                "shot_technique":
                    shot_data.get("technique", {}).get("name"),

                "dribble_outcome":
                    dribble_data.get("outcome", {}).get("name"),

                "duel_type":
                    duel_data.get("type", {}).get("name"),
            }

            writer.writerow(row)

            total_rows += 1
            match_rows += 1

        print(
            f"[{file_number}/{len(event_files)}] "
            f"Match {match_id}: {match_rows} events"
        )

print()
print(f"Created: {OUTPUT_FILE}")
print(f"Total event rows written: {total_rows}")