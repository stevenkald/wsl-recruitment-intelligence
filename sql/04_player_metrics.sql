-- 04_player_metrics.sql
-- Derive player-match production, progression and pressing metrics from events.

CREATE OR REPLACE VIEW analytics.v_player_match_shooting AS
SELECT
    match_id,
    player_id,
    COUNT(*) AS shots,
    COUNT(*) FILTER (WHERE shot_outcome = 'Goal') AS goals,
    COALESCE(SUM(shot_xg), 0) AS xg
FROM staging.events
WHERE event_type = 'Shot'
  AND player_id IS NOT NULL
GROUP BY match_id, player_id;

UPDATE warehouse.fact_player_match f
SET
    shots = s.shots,
    goals = s.goals,
    xg = s.xg
FROM analytics.v_player_match_shooting s
JOIN warehouse.dim_player p
    ON s.player_id = p.statsbomb_player_id
WHERE f.match_id = s.match_id
  AND f.player_key = p.player_key;

CREATE OR REPLACE VIEW analytics.v_player_match_passing AS
SELECT
    match_id,
    player_id,
    COUNT(*) AS passes,
    COUNT(*) FILTER (WHERE pass_outcome IS NULL) AS completed_passes,
    COUNT(*) FILTER (
        WHERE pass_shot_assist = TRUE
           OR pass_goal_assist = TRUE
    ) AS key_passes
FROM staging.events
WHERE event_type = 'Pass'
  AND player_id IS NOT NULL
GROUP BY match_id, player_id;

CREATE OR REPLACE VIEW analytics.v_player_match_xa AS
SELECT
    p.match_id,
    p.player_id,
    COUNT(*) AS chances_created,
    COALESCE(SUM(s.shot_xg), 0) AS xa
FROM staging.events p
JOIN staging.events s
    ON p.assisted_shot_id = s.event_id
WHERE p.event_type = 'Pass'
  AND s.event_type = 'Shot'
  AND p.player_id IS NOT NULL
GROUP BY p.match_id, p.player_id;

UPDATE warehouse.fact_player_match f
SET
    passes = p.pass_count,
    completed_passes = p.completed_passes,
    key_passes = p.key_passes
FROM (
    SELECT
        match_id,
        player_id,
        passes AS pass_count,
        completed_passes,
        key_passes
    FROM analytics.v_player_match_passing
) p
JOIN warehouse.dim_player dp
    ON p.player_id = dp.statsbomb_player_id
WHERE f.match_id = p.match_id
  AND f.player_key = dp.player_key;

UPDATE warehouse.fact_player_match f
SET xa = x.xa
FROM analytics.v_player_match_xa x
JOIN warehouse.dim_player dp
    ON x.player_id = dp.statsbomb_player_id
WHERE f.match_id = x.match_id
  AND f.player_key = dp.player_key;

-- Custom progression methodology:
-- StatsBomb pitch = 120 x 80; opposition goal centre = (120, 40).
-- A progressive pass/carry reduces straight-line distance to goal by >=10 units.
CREATE OR REPLACE VIEW analytics.v_player_match_progression AS
SELECT
    match_id,
    player_id,

    COUNT(*) FILTER (
        WHERE event_type = 'Pass'
          AND pass_outcome IS NULL
          AND end_x IS NOT NULL
          AND end_y IS NOT NULL
          AND (
              SQRT(POWER(120 - x, 2) + POWER(40 - y, 2))
              - SQRT(POWER(120 - end_x, 2) + POWER(40 - end_y, 2))
          ) >= 10
    ) AS progressive_passes,

    COUNT(*) FILTER (
        WHERE event_type = 'Carry'
          AND end_x IS NOT NULL
          AND end_y IS NOT NULL
          AND (
              SQRT(POWER(120 - x, 2) + POWER(40 - y, 2))
              - SQRT(POWER(120 - end_x, 2) + POWER(40 - end_y, 2))
          ) >= 10
    ) AS progressive_carries,

    COUNT(*) FILTER (
        WHERE event_type IN ('Pass', 'Carry')
          AND (event_type <> 'Pass' OR pass_outcome IS NULL)
          AND x < 80
          AND end_x >= 80
    ) AS final_third_entries,

    COUNT(*) FILTER (
        WHERE event_type IN ('Pass', 'Carry')
          AND (event_type <> 'Pass' OR pass_outcome IS NULL)
          AND NOT (x >= 102 AND y BETWEEN 18 AND 62)
          AND end_x >= 102
          AND end_y BETWEEN 18 AND 62
    ) AS box_entries

FROM staging.events
WHERE player_id IS NOT NULL
  AND event_type IN ('Pass', 'Carry')
GROUP BY match_id, player_id;

UPDATE warehouse.fact_player_match f
SET
    progressive_passes = p.progressive_passes,
    progressive_carries = p.progressive_carries,
    final_third_entries = p.final_third_entries,
    box_entries = p.box_entries
FROM analytics.v_player_match_progression p
JOIN warehouse.dim_player dp
    ON p.player_id = dp.statsbomb_player_id
WHERE f.match_id = p.match_id
  AND f.player_key = dp.player_key;

CREATE OR REPLACE VIEW analytics.v_player_match_defending AS
SELECT
    match_id,
    player_id,
    COUNT(*) FILTER (WHERE event_type = 'Pressure') AS pressures,
    COUNT(*) FILTER (
        WHERE event_type = 'Pressure'
          AND x >= 80
    ) AS high_pressures,
    COUNT(*) FILTER (
        WHERE event_type = 'Pressure'
          AND counterpress = TRUE
    ) AS counterpressures,
    COUNT(*) FILTER (WHERE event_type = 'Ball Recovery') AS ball_recoveries,
    COUNT(*) FILTER (WHERE event_type = 'Interception') AS interceptions
FROM staging.events
WHERE player_id IS NOT NULL
  AND event_type IN ('Pressure', 'Ball Recovery', 'Interception')
GROUP BY match_id, player_id;

UPDATE warehouse.fact_player_match f
SET
    pressures = d.pressures,
    high_pressures = d.high_pressures,
    counterpressures = d.counterpressures,
    ball_recoveries = d.ball_recoveries,
    interceptions = d.interceptions
FROM analytics.v_player_match_defending d
JOIN warehouse.dim_player dp
    ON d.player_id = dp.statsbomb_player_id
WHERE f.match_id = d.match_id
  AND f.player_key = dp.player_key;

-- Goal reconciliation: player shot-event goals intentionally exclude own goals.
SELECT
    (SELECT SUM(home_score + away_score) FROM staging.matches) AS official_goals,
    (SELECT SUM(goals) FROM warehouse.fact_player_match) AS player_shot_goals,
    (SELECT SUM(home_score + away_score) FROM staging.matches)
      - (SELECT SUM(goals) FROM warehouse.fact_player_match) AS non_player_goal_difference;
