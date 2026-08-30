import json
import csv
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

LINEUPS_FOLDER = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "statsbomb"
    / "lineups"
)

PLAYERS_OUTPUT = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "lineup_players_wsl_2023_24.csv"
)

POSITIONS_OUTPUT = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "lineup_positions_wsl_2023_24.csv"
)

lineup_files = sorted(LINEUPS_FOLDER.glob("*.json"))

print(f"Found {len(lineup_files)} lineup files.")

player_fields = [
    "match_id",
    "team_id",
    "team_name",
    "player_id",
    "player_name",
    "player_nickname",
    "jersey_number",
    "country_id",
    "country_name",
]

position_fields = [
    "match_id",
    "team_id",
    "team_name",
    "player_id",
    "player_name",
    "position_id",
    "position_name",
    "from_time",
    "to_time",
    "from_period",
    "to_period",
    "start_reason",
    "end_reason",
]

player_rows = 0
position_rows = 0

with (
    open(
        PLAYERS_OUTPUT,
        "w",
        newline="",
        encoding="utf-8"
    ) as player_file,
    open(
        POSITIONS_OUTPUT,
        "w",
        newline="",
        encoding="utf-8"
    ) as position_file
):

    player_writer = csv.DictWriter(
        player_file,
        fieldnames=player_fields
    )

    position_writer = csv.DictWriter(
        position_file,
        fieldnames=position_fields
    )

    player_writer.writeheader()
    position_writer.writeheader()

    for file_number, lineup_file in enumerate(lineup_files, start=1):

        match_id = int(lineup_file.stem)

        with open(lineup_file, "r", encoding="utf-8") as f:
            teams = json.load(f)

        for team in teams:

            team_id = team.get("team_id")
            team_name = team.get("team_name")

            for player in team.get("lineup", []):

                player_id = player.get("player_id")
                player_name = player.get("player_name")

                country = player.get("country") or {}

                player_writer.writerow({
                    "match_id": match_id,
                    "team_id": team_id,
                    "team_name": team_name,
                    "player_id": player_id,
                    "player_name": player_name,
                    "player_nickname": player.get("player_nickname"),
                    "jersey_number": player.get("jersey_number"),
                    "country_id": country.get("id"),
                    "country_name": country.get("name"),
                })

                player_rows += 1

                for position in player.get("positions", []):

                    position_writer.writerow({
                        "match_id": match_id,
                        "team_id": team_id,
                        "team_name": team_name,
                        "player_id": player_id,
                        "player_name": player_name,
                        "position_id": position.get("position_id"),
                        "position_name": position.get("position"),
                        "from_time": position.get("from"),
                        "to_time": position.get("to"),
                        "from_period": position.get("from_period"),
                        "to_period": position.get("to_period"),
                        "start_reason": position.get("start_reason"),
                        "end_reason": position.get("end_reason"),
                    })

                    position_rows += 1

        print(
            f"[{file_number}/{len(lineup_files)}] "
            f"Match {match_id}"
        )

print()
print(f"Player-match rows written: {player_rows}")
print(f"Position-spell rows written: {position_rows}")
print("Finished.")