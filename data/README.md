# Data

Raw StatsBomb files and generated CSVs are intentionally excluded from Git.

Run the ETL scripts in `../etl/` to recreate them locally.

Expected folders after download / processing:

```text
data/
├── raw/
│   └── statsbomb/
│       ├── wsl_2023_24.json
│       ├── events/
│       │   └── <match_id>.json
│       └── lineups/
│           └── <match_id>.json
└── processed/
    ├── matches_wsl_2023_24.csv
    ├── events_wsl_2023_24.csv
    ├── lineup_players_wsl_2023_24.csv
    ├── lineup_positions_wsl_2023_24.csv
    └── player_minutes_wsl_2023_24.csv
```

The completed project build produced 132 matches and 495,189 flattened event rows.
