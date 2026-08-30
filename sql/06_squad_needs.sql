-- 06_squad_needs.sql
-- Identify where each club-position group is below the league benchmark and
-- convert those gaps into recruitment-priority weights.

DROP TABLE IF EXISTS analytics.club_position_profiles CASCADE;

CREATE TABLE analytics.club_position_profiles AS
SELECT
    team_key,
    position_group,
    COUNT(*) AS eligible_players,
    ROUND(AVG(finishing_score)::NUMERIC, 1) AS finishing_score,
    ROUND(AVG(creativity_score)::NUMERIC, 1) AS creativity_score,
    ROUND(AVG(progression_score)::NUMERIC, 1) AS progression_score,
    ROUND(AVG(pressing_score)::NUMERIC, 1) AS pressing_score,
    ROUND(AVG(possession_security_score)::NUMERIC, 1) AS possession_security_score
FROM analytics.player_attributes
GROUP BY team_key, position_group;

DROP TABLE IF EXISTS analytics.position_benchmarks CASCADE;

CREATE TABLE analytics.position_benchmarks AS
SELECT
    position_group,
    ROUND(AVG(finishing_score)::NUMERIC, 1) AS benchmark_finishing,
    ROUND(AVG(creativity_score)::NUMERIC, 1) AS benchmark_creativity,
    ROUND(AVG(progression_score)::NUMERIC, 1) AS benchmark_progression,
    ROUND(AVG(pressing_score)::NUMERIC, 1) AS benchmark_pressing,
    ROUND(AVG(possession_security_score)::NUMERIC, 1) AS benchmark_security
FROM analytics.player_attributes
GROUP BY position_group;

DROP TABLE IF EXISTS analytics.squad_needs CASCADE;

CREATE TABLE analytics.squad_needs AS
WITH gaps AS (
    SELECT
        cp.team_key,
        cp.position_group,
        cp.eligible_players,

        cp.finishing_score,
        cp.creativity_score,
        cp.progression_score,
        cp.pressing_score,
        cp.possession_security_score,

        pb.benchmark_finishing,
        pb.benchmark_creativity,
        pb.benchmark_progression,
        pb.benchmark_pressing,
        pb.benchmark_security,

        GREATEST(pb.benchmark_finishing - cp.finishing_score, 0) AS finishing_gap,
        GREATEST(pb.benchmark_creativity - cp.creativity_score, 0) AS creativity_gap,
        GREATEST(pb.benchmark_progression - cp.progression_score, 0) AS progression_gap,
        GREATEST(pb.benchmark_pressing - cp.pressing_score, 0) AS pressing_gap,
        GREATEST(pb.benchmark_security - cp.possession_security_score, 0) AS security_gap

    FROM analytics.club_position_profiles cp
    JOIN analytics.position_benchmarks pb
        ON cp.position_group = pb.position_group
),
weighted AS (
    SELECT
        *,
        finishing_gap + creativity_gap + progression_gap + pressing_gap + security_gap
            AS total_gap
    FROM gaps
)
SELECT
    team_key,
    position_group,
    eligible_players,

    finishing_score,
    creativity_score,
    progression_score,
    pressing_score,
    possession_security_score,

    benchmark_finishing,
    benchmark_creativity,
    benchmark_progression,
    benchmark_pressing,
    benchmark_security,

    finishing_gap,
    creativity_gap,
    progression_gap,
    pressing_gap,
    security_gap,

    finishing_gap / NULLIF(total_gap, 0) AS finishing_weight,
    creativity_gap / NULLIF(total_gap, 0) AS creativity_weight,
    progression_gap / NULLIF(total_gap, 0) AS progression_weight,
    pressing_gap / NULLIF(total_gap, 0) AS pressing_weight,
    security_gap / NULLIF(total_gap, 0) AS security_weight

FROM weighted;

-- Weights should sum to ~1 when a group has at least one below-benchmark gap.
SELECT
    team_key,
    position_group,
    ROUND((
        COALESCE(finishing_weight, 0)
      + COALESCE(creativity_weight, 0)
      + COALESCE(progression_weight, 0)
      + COALESCE(pressing_weight, 0)
      + COALESCE(security_weight, 0)
    )::NUMERIC, 4) AS weight_sum
FROM analytics.squad_needs
ORDER BY team_key, position_group;
