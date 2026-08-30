-- 05_percentiles_attributes.sql
-- Aggregate player-season output, convert to per-90 metrics, compare within
-- position groups, then build five interpretable player attribute scores.

CREATE OR REPLACE VIEW analytics.v_player_primary_season_position AS
WITH position_counts AS (
    SELECT
        f.player_key,
        f.team_key,
        p.position_group,
        COUNT(*) AS matches_in_position
    FROM warehouse.fact_player_match f
    JOIN warehouse.dim_position p
        ON f.position_key = p.position_key
    WHERE p.position_group <> 'Other'
    GROUP BY f.player_key, f.team_key, p.position_group
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY player_key, team_key
            ORDER BY matches_in_position DESC, position_group
        ) AS position_rank
    FROM position_counts
)
SELECT
    player_key,
    team_key,
    position_group,
    matches_in_position
FROM ranked
WHERE position_rank = 1;

DROP TABLE IF EXISTS analytics.player_season_metrics CASCADE;

CREATE TABLE analytics.player_season_metrics AS
SELECT
    f.player_key,
    f.team_key,
    pos.position_group,

    COUNT(*) AS appearances,
    COUNT(*) FILTER (WHERE f.started = TRUE) AS starts,
    SUM(f.minutes_played) AS minutes,

    SUM(f.shots) AS shots,
    SUM(f.goals) AS goals,
    SUM(f.xg) AS xg,

    SUM(f.passes) AS passes,
    SUM(f.completed_passes) AS completed_passes,
    SUM(f.key_passes) AS key_passes,
    SUM(f.xa) AS xa,

    SUM(f.progressive_passes) AS progressive_passes,
    SUM(f.progressive_carries) AS progressive_carries,
    SUM(f.final_third_entries) AS final_third_entries,
    SUM(f.box_entries) AS box_entries,

    SUM(f.pressures) AS pressures,
    SUM(f.high_pressures) AS high_pressures,
    SUM(f.counterpressures) AS counterpressures,
    SUM(f.ball_recoveries) AS recoveries,
    SUM(f.interceptions) AS interceptions,

    SUM(f.dribbles) AS dribbles,
    SUM(f.successful_dribbles) AS successful_dribbles,
    SUM(f.turnovers) AS turnovers

FROM warehouse.fact_player_match f
LEFT JOIN analytics.v_player_primary_season_position pos
    ON f.player_key = pos.player_key
   AND f.team_key = pos.team_key
GROUP BY f.player_key, f.team_key, pos.position_group;

ALTER TABLE analytics.player_season_metrics
    ADD COLUMN shots_per90 NUMERIC,
    ADD COLUMN goals_per90 NUMERIC,
    ADD COLUMN xg_per90 NUMERIC,
    ADD COLUMN xa_per90 NUMERIC,
    ADD COLUMN key_passes_per90 NUMERIC,
    ADD COLUMN progressive_passes_per90 NUMERIC,
    ADD COLUMN progressive_carries_per90 NUMERIC,
    ADD COLUMN final_third_entries_per90 NUMERIC,
    ADD COLUMN box_entries_per90 NUMERIC,
    ADD COLUMN pressures_per90 NUMERIC,
    ADD COLUMN high_pressures_per90 NUMERIC,
    ADD COLUMN counterpressures_per90 NUMERIC,
    ADD COLUMN recoveries_per90 NUMERIC,
    ADD COLUMN interceptions_per90 NUMERIC,
    ADD COLUMN pass_completion_pct NUMERIC;

UPDATE analytics.player_season_metrics
SET
    shots_per90 = shots * 90.0 / NULLIF(minutes, 0),
    goals_per90 = goals * 90.0 / NULLIF(minutes, 0),
    xg_per90 = xg * 90.0 / NULLIF(minutes, 0),
    xa_per90 = xa * 90.0 / NULLIF(minutes, 0),
    key_passes_per90 = key_passes * 90.0 / NULLIF(minutes, 0),
    progressive_passes_per90 = progressive_passes * 90.0 / NULLIF(minutes, 0),
    progressive_carries_per90 = progressive_carries * 90.0 / NULLIF(minutes, 0),
    final_third_entries_per90 = final_third_entries * 90.0 / NULLIF(minutes, 0),
    box_entries_per90 = box_entries * 90.0 / NULLIF(minutes, 0),
    pressures_per90 = pressures * 90.0 / NULLIF(minutes, 0),
    high_pressures_per90 = high_pressures * 90.0 / NULLIF(minutes, 0),
    counterpressures_per90 = counterpressures * 90.0 / NULLIF(minutes, 0),
    recoveries_per90 = recoveries * 90.0 / NULLIF(minutes, 0),
    interceptions_per90 = interceptions * 90.0 / NULLIF(minutes, 0),
    pass_completion_pct = 100.0 * completed_passes / NULLIF(passes, 0);

DROP TABLE IF EXISTS analytics.player_percentiles CASCADE;

CREATE TABLE analytics.player_percentiles AS
SELECT
    s.*,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.xg_per90
    ))::NUMERIC, 1) AS pct_xg,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.xa_per90
    ))::NUMERIC, 1) AS pct_xa,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.key_passes_per90
    ))::NUMERIC, 1) AS pct_key_passes,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.progressive_passes_per90
    ))::NUMERIC, 1) AS pct_progressive_passes,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.progressive_carries_per90
    ))::NUMERIC, 1) AS pct_progressive_carries,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.final_third_entries_per90
    ))::NUMERIC, 1) AS pct_final_third_entries,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.box_entries_per90
    ))::NUMERIC, 1) AS pct_box_entries,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.pressures_per90
    ))::NUMERIC, 1) AS pct_pressures,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.high_pressures_per90
    ))::NUMERIC, 1) AS pct_high_pressures,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.counterpressures_per90
    ))::NUMERIC, 1) AS pct_counterpressures,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.recoveries_per90
    ))::NUMERIC, 1) AS pct_recoveries,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.interceptions_per90
    ))::NUMERIC, 1) AS pct_interceptions,

    ROUND((100 * PERCENT_RANK() OVER (
        PARTITION BY s.position_group ORDER BY s.pass_completion_pct
    ))::NUMERIC, 1) AS pct_pass_completion

FROM analytics.player_season_metrics s
WHERE s.minutes >= 900
  AND s.position_group IS NOT NULL
  AND s.position_group <> 'Other';

DROP TABLE IF EXISTS analytics.player_attributes CASCADE;

CREATE TABLE analytics.player_attributes AS
SELECT
    p.player_key,
    p.team_key,
    p.position_group,
    p.minutes,

    ROUND((
        0.70 * p.pct_xg
      + 0.10 * p.pct_key_passes
      + 0.20 * p.pct_box_entries
    )::NUMERIC, 1) AS finishing_score,

    ROUND((
        0.50 * p.pct_xa
      + 0.35 * p.pct_key_passes
      + 0.15 * p.pct_box_entries
    )::NUMERIC, 1) AS creativity_score,

    ROUND((
        0.45 * p.pct_progressive_passes
      + 0.35 * p.pct_progressive_carries
      + 0.20 * p.pct_final_third_entries
    )::NUMERIC, 1) AS progression_score,

    ROUND((
        0.40 * p.pct_pressures
      + 0.35 * p.pct_high_pressures
      + 0.25 * p.pct_counterpressures
    )::NUMERIC, 1) AS pressing_score,

    ROUND((
        0.60 * p.pct_pass_completion
      + 0.20 * p.pct_recoveries
      + 0.20 * p.pct_interceptions
    )::NUMERIC, 1) AS possession_security_score

FROM analytics.player_percentiles p;

-- Inspect sample size within each comparison group.
SELECT position_group, COUNT(*) AS eligible_players
FROM analytics.player_percentiles
GROUP BY position_group
ORDER BY eligible_players DESC;
