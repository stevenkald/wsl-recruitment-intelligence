-- 03_fact_player_match.sql
-- Build the player-match fact table at one row per player appearance per match.

CREATE OR REPLACE VIEW analytics.v_match_end AS
SELECT
    match_id,
    MAX(minute * 60 + second)::NUMERIC AS match_end_seconds
FROM staging.events
GROUP BY match_id;

-- Primary position in a match = the position attached to the greatest number
-- of that player's on-ball/off-ball event records in the match.
CREATE OR REPLACE VIEW analytics.v_player_match_primary_position AS
WITH position_counts AS (
    SELECT
        match_id,
        player_id,
        position_id,
        COUNT(*) AS event_count
    FROM staging.events
    WHERE player_id IS NOT NULL
      AND position_id IS NOT NULL
    GROUP BY match_id, player_id, position_id
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY match_id, player_id
            ORDER BY event_count DESC, position_id
        ) AS position_rank
    FROM position_counts
)
SELECT
    match_id,
    player_id,
    position_id,
    event_count
FROM ranked
WHERE position_rank = 1;

DROP TABLE IF EXISTS warehouse.fact_player_match CASCADE;

CREATE TABLE warehouse.fact_player_match (
    player_match_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    match_id BIGINT NOT NULL,
    player_key INTEGER NOT NULL,
    team_key INTEGER NOT NULL,
    position_key INTEGER,
    started BOOLEAN,
    minutes_played NUMERIC,

    shots INTEGER DEFAULT 0,
    goals INTEGER DEFAULT 0,
    xg NUMERIC DEFAULT 0,

    passes INTEGER DEFAULT 0,
    completed_passes INTEGER DEFAULT 0,
    key_passes INTEGER DEFAULT 0,
    xa NUMERIC DEFAULT 0,

    progressive_passes INTEGER DEFAULT 0,
    progressive_carries INTEGER DEFAULT 0,
    final_third_entries INTEGER DEFAULT 0,
    box_entries INTEGER DEFAULT 0,

    pressures INTEGER DEFAULT 0,
    high_pressures INTEGER DEFAULT 0,
    counterpressures INTEGER DEFAULT 0,
    ball_recoveries INTEGER DEFAULT 0,
    interceptions INTEGER DEFAULT 0,

    dribbles INTEGER DEFAULT 0,
    successful_dribbles INTEGER DEFAULT 0,
    turnovers INTEGER DEFAULT 0,

    FOREIGN KEY (player_key) REFERENCES warehouse.dim_player(player_key),
    FOREIGN KEY (team_key) REFERENCES warehouse.dim_team(team_key),
    FOREIGN KEY (position_key) REFERENCES warehouse.dim_position(position_key),
    UNIQUE (match_id, player_key)
);

INSERT INTO warehouse.fact_player_match (
    match_id,
    player_key,
    team_key,
    position_key,
    started,
    minutes_played
)
SELECT
    pm.match_id,
    p.player_key,
    t.team_key,
    pos.position_key,
    pm.started,
    pm.minutes_played
FROM staging.player_minutes pm
JOIN warehouse.dim_player p
    ON pm.player_id = p.statsbomb_player_id
JOIN warehouse.dim_team t
    ON pm.team_id = t.statsbomb_team_id
LEFT JOIN analytics.v_player_match_primary_position primary_pos
    ON pm.match_id = primary_pos.match_id
   AND pm.player_id = primary_pos.player_id
LEFT JOIN warehouse.dim_position pos
    ON primary_pos.position_id = pos.statsbomb_position_id;

-- Core grain/data-quality checks.
SELECT
    COUNT(*) AS player_match_rows,
    COUNT(DISTINCT match_id) AS matches,
    MIN(minutes_played) AS min_minutes,
    MAX(minutes_played) AS max_minutes,
    COUNT(*) FILTER (WHERE position_key IS NULL) AS missing_positions
FROM warehouse.fact_player_match;

-- Every match should start with 22 players.
SELECT
    match_id,
    COUNT(*) FILTER (WHERE started = TRUE) AS starters
FROM staging.player_minutes
GROUP BY match_id
HAVING COUNT(*) FILTER (WHERE started = TRUE) <> 22;
