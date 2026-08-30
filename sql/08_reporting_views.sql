-- 08_reporting_views.sql
-- Clean reporting layer consumed by Power BI.

CREATE OR REPLACE VIEW analytics.v_recruitment_candidates AS
SELECT
    rf.target_team_key,
    target.team_name AS target_club,

    rf.candidate_player_key AS player_key,
    player.player_name,

    rf.candidate_team_key AS current_team_key,
    current_team.team_name AS current_club,

    rf.position_group,
    rf.minutes,

    rf.finishing_score,
    rf.creativity_score,
    rf.progression_score,
    rf.pressing_score,
    rf.possession_security_score,

    rf.finishing_weight,
    rf.creativity_weight,
    rf.progression_weight,
    rf.pressing_weight,
    rf.security_weight,

    rf.sporting_fit_score,
    rf.sporting_fit_rank,

    sm.appearances,
    sm.starts,
    sm.goals,
    sm.xg,
    sm.xa,
    sm.goals_per90,
    sm.xg_per90,
    sm.xa_per90,
    sm.key_passes_per90,
    sm.progressive_passes_per90,
    sm.progressive_carries_per90,
    sm.final_third_entries_per90,
    sm.box_entries_per90,
    sm.pressures_per90,
    sm.high_pressures_per90,
    sm.counterpressures_per90,
    sm.recoveries_per90,
    sm.interceptions_per90,
    sm.pass_completion_pct

FROM analytics.recruitment_sporting_fit rf
JOIN warehouse.dim_player player
    ON rf.candidate_player_key = player.player_key
JOIN warehouse.dim_team target
    ON rf.target_team_key = target.team_key
JOIN warehouse.dim_team current_team
    ON rf.candidate_team_key = current_team.team_key
JOIN analytics.player_season_metrics sm
    ON rf.candidate_player_key = sm.player_key
   AND rf.candidate_team_key = sm.team_key;

CREATE OR REPLACE VIEW analytics.v_squad_needs_report AS
SELECT
    sn.team_key,
    t.team_name,
    sn.position_group,
    sn.eligible_players,

    sn.finishing_score,
    sn.creativity_score,
    sn.progression_score,
    sn.pressing_score,
    sn.possession_security_score,

    sn.benchmark_finishing,
    sn.benchmark_creativity,
    sn.benchmark_progression,
    sn.benchmark_pressing,
    sn.benchmark_security,

    sn.finishing_gap,
    sn.creativity_gap,
    sn.progression_gap,
    sn.pressing_gap,
    sn.security_gap,

    sn.finishing_weight,
    sn.creativity_weight,
    sn.progression_weight,
    sn.pressing_weight,
    sn.security_weight

FROM analytics.squad_needs sn
JOIN warehouse.dim_team t
    ON sn.team_key = t.team_key;

CREATE OR REPLACE VIEW analytics.v_player_profiles AS
SELECT
    p.player_key,
    p.player_name,
    t.team_key,
    t.team_name,
    pa.position_group,

    sm.appearances,
    sm.starts,
    sm.minutes,
    sm.goals,
    sm.xg,
    sm.xa,
    sm.goals_per90,
    sm.xg_per90,
    sm.xa_per90,
    sm.key_passes_per90,
    sm.progressive_passes_per90,
    sm.progressive_carries_per90,
    sm.final_third_entries_per90,
    sm.box_entries_per90,
    sm.pressures_per90,
    sm.high_pressures_per90,
    sm.counterpressures_per90,
    sm.recoveries_per90,
    sm.interceptions_per90,
    sm.pass_completion_pct,

    pa.finishing_score,
    pa.creativity_score,
    pa.progression_score,
    pa.pressing_score,
    pa.possession_security_score

FROM analytics.player_attributes pa
JOIN warehouse.dim_player p
    ON pa.player_key = p.player_key
JOIN warehouse.dim_team t
    ON pa.team_key = t.team_key
JOIN analytics.player_season_metrics sm
    ON pa.player_key = sm.player_key
   AND pa.team_key = sm.team_key;

-- Expected build: ~1,310 recruitment candidate rows.
SELECT COUNT(*) AS recruitment_candidate_rows
FROM analytics.v_recruitment_candidates;
