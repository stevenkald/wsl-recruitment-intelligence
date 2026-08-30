-- 02_dimensions.sql
-- Create clean player/team/position dimensions for the warehouse layer.

DROP TABLE IF EXISTS warehouse.dim_position CASCADE;
DROP TABLE IF EXISTS warehouse.dim_team CASCADE;
DROP TABLE IF EXISTS warehouse.dim_player CASCADE;

CREATE TABLE warehouse.dim_player (
    player_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    statsbomb_player_id INTEGER UNIQUE NOT NULL,
    player_name TEXT NOT NULL,
    player_nickname TEXT,
    country_name TEXT
);

INSERT INTO warehouse.dim_player (
    statsbomb_player_id,
    player_name,
    player_nickname,
    country_name
)
SELECT DISTINCT ON (player_id)
    player_id,
    player_name,
    player_nickname,
    country_name
FROM staging.lineup_players
WHERE player_id IS NOT NULL
ORDER BY player_id, match_id;

CREATE TABLE warehouse.dim_team (
    team_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    statsbomb_team_id INTEGER UNIQUE NOT NULL,
    team_name TEXT NOT NULL
);

INSERT INTO warehouse.dim_team (statsbomb_team_id, team_name)
SELECT DISTINCT ON (team_id)
    team_id,
    team_name
FROM staging.lineup_players
WHERE team_id IS NOT NULL
ORDER BY team_id, match_id;

CREATE TABLE warehouse.dim_position (
    position_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    statsbomb_position_id INTEGER UNIQUE NOT NULL,
    position_name TEXT NOT NULL,
    position_group TEXT NOT NULL
);

INSERT INTO warehouse.dim_position (
    statsbomb_position_id,
    position_name,
    position_group
)
SELECT DISTINCT ON (position_id)
    position_id,
    position_name,
    CASE
        WHEN position_name = 'Goalkeeper' THEN 'Goalkeeper'

        WHEN position_name IN (
            'Left Center Back', 'Center Back', 'Right Center Back'
        ) THEN 'Centre Back'

        WHEN position_name IN (
            'Left Back', 'Right Back'
        ) THEN 'Full Back'

        WHEN position_name IN (
            'Left Wing Back', 'Right Wing Back'
        ) THEN 'Wing Back'

        WHEN position_name IN (
            'Left Defensive Midfield', 'Center Defensive Midfield',
            'Right Defensive Midfield'
        ) THEN 'Defensive Midfield'

        WHEN position_name IN (
            'Left Center Midfield', 'Center Midfield', 'Right Center Midfield'
        ) THEN 'Central Midfield'

        WHEN position_name IN (
            'Left Attacking Midfield', 'Center Attacking Midfield',
            'Right Attacking Midfield'
        ) THEN 'Attacking Midfield'

        WHEN position_name IN (
            'Left Wing', 'Right Wing', 'Left Midfield', 'Right Midfield'
        ) THEN 'Winger'

        WHEN position_name IN (
            'Left Center Forward', 'Center Forward', 'Right Center Forward',
            'Left Forward', 'Right Forward'
        ) THEN 'Striker'

        ELSE 'Other'
    END AS position_group
FROM staging.lineup_positions
WHERE position_id IS NOT NULL
  AND position_name IS NOT NULL
ORDER BY position_id, match_id;

-- Validation
SELECT 'players' AS object, COUNT(*) AS row_count FROM warehouse.dim_player
UNION ALL
SELECT 'teams', COUNT(*) FROM warehouse.dim_team
UNION ALL
SELECT 'positions', COUNT(*) FROM warehouse.dim_position;
