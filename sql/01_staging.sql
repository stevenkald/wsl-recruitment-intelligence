-- 01_staging.sql
-- Database foundation and raw CSV landing tables.
-- Run this first in the football_recruitment PostgreSQL database.

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS staging.player_minutes;
DROP TABLE IF EXISTS staging.lineup_positions;
DROP TABLE IF EXISTS staging.lineup_players;
DROP TABLE IF EXISTS staging.events;
DROP TABLE IF EXISTS staging.matches;

CREATE TABLE staging.matches (
    match_id BIGINT PRIMARY KEY,
    match_date DATE,
    kick_off TIME,
    match_week INTEGER,
    competition_id INTEGER,
    competition_name TEXT,
    season_id INTEGER,
    season_name TEXT,
    home_team_id INTEGER,
    home_team_name TEXT,
    away_team_id INTEGER,
    away_team_name TEXT,
    home_score INTEGER,
    away_score INTEGER,
    stadium TEXT,
    referee TEXT
);

CREATE TABLE staging.events (
    event_id UUID PRIMARY KEY,
    match_id BIGINT NOT NULL,
    event_index INTEGER,
    period INTEGER,
    minute INTEGER,
    second INTEGER,
    possession INTEGER,
    possession_team_id INTEGER,
    team_id INTEGER,
    player_id INTEGER,
    position_id INTEGER,
    event_type TEXT,
    play_pattern TEXT,
    x NUMERIC,
    y NUMERIC,
    end_x NUMERIC,
    end_y NUMERIC,
    under_pressure BOOLEAN,
    counterpress BOOLEAN,
    pass_recipient_id INTEGER,
    pass_length NUMERIC,
    pass_angle NUMERIC,
    pass_height TEXT,
    pass_outcome TEXT,
    pass_type TEXT,
    pass_cross BOOLEAN,
    pass_cut_back BOOLEAN,
    pass_shot_assist BOOLEAN,
    pass_goal_assist BOOLEAN,
    assisted_shot_id UUID,
    shot_xg NUMERIC,
    shot_outcome TEXT,
    shot_body_part TEXT,
    shot_technique TEXT,
    dribble_outcome TEXT,
    duel_type TEXT
);

CREATE TABLE staging.lineup_players (
    match_id BIGINT NOT NULL,
    team_id INTEGER,
    team_name TEXT,
    player_id INTEGER NOT NULL,
    player_name TEXT,
    player_nickname TEXT,
    jersey_number INTEGER,
    country_id INTEGER,
    country_name TEXT
);

CREATE TABLE staging.lineup_positions (
    match_id BIGINT NOT NULL,
    team_id INTEGER,
    team_name TEXT,
    player_id INTEGER NOT NULL,
    player_name TEXT,
    position_id INTEGER,
    position_name TEXT,
    from_time TEXT,
    to_time TEXT,
    from_period INTEGER,
    to_period INTEGER,
    start_reason TEXT,
    end_reason TEXT
);

CREATE TABLE staging.player_minutes (
    match_id BIGINT NOT NULL,
    team_id INTEGER NOT NULL,
    player_id INTEGER NOT NULL,
    player_name TEXT,
    started BOOLEAN,
    starting_position_id INTEGER,
    starting_position_name TEXT,
    on_second INTEGER,
    off_second INTEGER,
    minutes_played NUMERIC
);

-- Import the five generated CSVs from data/processed/ using pgAdmin's
-- Import/Export Data tool (CSV, Header = Yes), or equivalent COPY commands.
-- Expected project-build row counts:
--   matches:            132
--   events:         495,189
--   lineup_players:   5,101
--   lineup_positions: 5,862
--   player_minutes:   3,894
