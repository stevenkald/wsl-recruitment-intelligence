-- 07_recruitment_model.sql
-- Rank external candidates according to the specific weaknesses of each
-- target club-position group.

DROP TABLE IF EXISTS analytics.recruitment_sporting_fit CASCADE;

CREATE TABLE analytics.recruitment_sporting_fit AS
WITH candidate_scores AS (
    SELECT
        sn.team_key AS target_team_key,
        sn.position_group,

        pa.player_key AS candidate_player_key,
        pa.team_key AS candidate_team_key,
        pa.minutes,

        pa.finishing_score,
        pa.creativity_score,
        pa.progression_score,
        pa.pressing_score,
        pa.possession_security_score,

        COALESCE(sn.finishing_weight, 0.20) AS finishing_weight,
        COALESCE(sn.creativity_weight, 0.20) AS creativity_weight,
        COALESCE(sn.progression_weight, 0.20) AS progression_weight,
        COALESCE(sn.pressing_weight, 0.20) AS pressing_weight,
        COALESCE(sn.security_weight, 0.20) AS security_weight,

        ROUND((
            pa.finishing_score * COALESCE(sn.finishing_weight, 0.20)
          + pa.creativity_score * COALESCE(sn.creativity_weight, 0.20)
          + pa.progression_score * COALESCE(sn.progression_weight, 0.20)
          + pa.pressing_score * COALESCE(sn.pressing_weight, 0.20)
          + pa.possession_security_score * COALESCE(sn.security_weight, 0.20)
        )::NUMERIC, 1) AS sporting_fit_score

    FROM analytics.squad_needs sn
    JOIN analytics.player_attributes pa
        ON sn.position_group = pa.position_group
    WHERE pa.team_key <> sn.team_key
)
SELECT
    *,
    DENSE_RANK() OVER (
        PARTITION BY target_team_key, position_group
        ORDER BY sporting_fit_score DESC
    ) AS sporting_fit_rank
FROM candidate_scores;

-- Quick sanity check: top candidate by target club and position.
SELECT
    target_team_key,
    position_group,
    candidate_player_key,
    sporting_fit_score
FROM analytics.recruitment_sporting_fit
WHERE sporting_fit_rank = 1
ORDER BY target_team_key, position_group;
