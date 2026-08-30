import json
import csv
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "statsbomb"
    / "wsl_2023_24.json"
)

OUTPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "matches_wsl_2023_24.csv"
)

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    matches = json.load(f)

rows = []

for match in matches:

    row = {
        "match_id": match.get("match_id"),
        "match_date": match.get("match_date"),
        "kick_off": match.get("kick_off"),
        "match_week": match.get("match_week"),

        "competition_id": match.get("competition", {}).get("competition_id"),
        "competition_name": match.get("competition", {}).get("competition_name"),

        "season_id": match.get("season", {}).get("season_id"),
        "season_name": match.get("season", {}).get("season_name"),

        "home_team_id": match.get("home_team", {}).get("home_team_id"),
        "home_team_name": match.get("home_team", {}).get("home_team_name"),

        "away_team_id": match.get("away_team", {}).get("away_team_id"),
        "away_team_name": match.get("away_team", {}).get("away_team_name"),

        "home_score": match.get("home_score"),
        "away_score": match.get("away_score"),

        "stadium": match.get("stadium", {}).get("name"),
        "referee": match.get("referee", {}).get("name"),
    }

    rows.append(row)

fieldnames = rows[0].keys()

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

print(f"Created {OUTPUT_FILE}")
print(f"Matches written: {len(rows)}")