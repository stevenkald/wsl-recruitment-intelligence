# Methodology

## 1. Objective

The project answers a recruitment question rather than simply ranking the league's best players:

> **For a selected WSL club and position group, which external players best address that squad group's relative weaknesses?**

The model therefore separates **player quality** from **club-specific fit**. A candidate can rank highly for one club but lower for another because the target clubs have different weaknesses.

---

## 2. Data scope

- Competition: Women's Super League
- Season: 2023/24
- StatsBomb competition ID: `37`
- StatsBomb season ID: `281`
- Matches: `132`
- Flattened event records in the completed build: `495,189`
- Distinct players appearing in lineup files: `336`
- Player-match appearances reconstructed from events: `3,894`

Raw event and lineup JSON is downloaded from **StatsBomb Open Data** and is not committed to this repository.

---

## 3. Data architecture

The pipeline is deliberately separated into layers:

1. **Raw** — StatsBomb JSON files.
2. **Python ETL** — flatten nested JSON into analysis-friendly CSVs.
3. **PostgreSQL staging** — preserve source-level fields at clear grains.
4. **Warehouse** — clean player/team/position dimensions and a player-match fact table.
5. **Analytics** — per-90 metrics, percentiles, attribute scores, squad gaps and recruitment scores.
6. **Reporting views** — simplified datasets exposed to Power BI.
7. **Power BI** — interactive filters, DAX measures and presentation.

The main fact-table grain is **one player appearance per match**. Keeping the grain explicit prevents accidental many-to-many joins and inflated totals.

---

## 4. Playing-time reconstruction

### Problem found

The source lineup-position records contain `from` / `to` timing fields for tactical position spells. During validation, some tactical-shift rows produced impossible negative durations because the source fields could move backwards across periods (for example, a second-half `from` time paired with a first-half `to` time).

Rather than silently correcting individual rows, the project changed the source used for minutes.

### Event-based approach

Playing time is reconstructed from:

- **Starting XI** events → player starts at second 0.
- **Substitution** events → outgoing player ends at the substitution time; replacement begins then.
- **Red card / second yellow** events → dismissed player's interval ends at the card time.
- Match end → maximum event timestamp for the match.

Lineup/event position information is still used for positional classification, but not for playing-time duration.

### Validation

The completed build produced:

- `3,894` player-match appearances.
- `132` distinct matches.
- exactly `22` starters in every match.
- no negative playing-time values.
- a maximum appearance duration of roughly `107` minutes, consistent with matches containing stoppage time.

---

## 5. Position classification

StatsBomb's detailed positions are mapped into broader recruitment groups:

- Goalkeeper
- Centre Back
- Full Back
- Wing Back
- Defensive Midfield
- Central Midfield
- Attacking Midfield
- Winger
- Striker

For each match, a player's primary position is the position attached to the **largest number of their event records** in that match.

The player's season position group is then the group in which they made the most player-match appearances for that club.

This is a pragmatic classification method: it avoids relying on the inconsistent tactical-spell durations while still using the positional context embedded in the event data.

---

## 6. Core player metrics

### Shooting

- Shots
- Goals
- Expected goals (`xG`)

### Creation and passing

- Passes
- Completed passes
- Key passes
- Expected assists (`xA`)

`xA` is calculated by joining an assisted pass to the shot it created using StatsBomb's `assisted_shot_id`, then assigning the shot's xG value to the passer.

### Progression

The project defines a progressive pass/carry as an action that reduces straight-line distance to the opposition goal centre by at least **10 StatsBomb coordinate units**.

StatsBomb pitch coordinates are treated as `120 x 80`, so the opposition goal centre is:

```text
(120, 40)
```

Distance to goal:

```text
sqrt((120 - x)^2 + (40 - y)^2)
```

Progressive action condition:

```text
start_distance - end_distance >= 10
```

Additional progression metrics:

- Final-third entries: action starts before `x = 80` and ends at/after `x = 80`.
- Box entries: action starts outside and ends inside the approximate box (`x >= 102`, `18 <= y <= 62`).
- Failed passes are excluded from completed-pass progression/entry metrics.

These are **project-defined analytical rules**, not proprietary StatsBomb metrics.

### Pressing / defensive activity

- Pressures
- High pressures (`x >= 80`)
- Counterpressures
- Ball recoveries
- Interceptions

---

## 7. Per-90 normalisation

Raw totals favour players with more minutes, so season metrics are converted to per-90 values:

```text
metric_per90 = metric * 90 / minutes_played
```

Only players with at least **900 minutes** for the analysed player-team season are eligible for percentile comparison and recruitment scoring.

The threshold reduces small-sample distortion while retaining a useful recruitment pool.

---

## 8. Position-adjusted percentiles

Players are compared only with others in the same broad position group.

For each metric, PostgreSQL's `PERCENT_RANK()` window function is calculated with:

```sql
PARTITION BY position_group
ORDER BY metric
```

and converted to a `0–100` score.

This prevents structurally different roles — for example centre-backs and strikers — from being evaluated on the same raw distribution.

---

## 9. Player attribute scores

Percentiles are combined into five interpretable attributes. The weights are modelling assumptions chosen for this portfolio project and are documented rather than presented as objective truth.

### Finishing

```text
70% xG percentile
10% key-pass percentile
20% box-entry percentile
```

### Creativity

```text
50% xA percentile
35% key-pass percentile
15% box-entry percentile
```

### Progression

```text
45% progressive-passes percentile
35% progressive-carries percentile
20% final-third-entries percentile
```

### Pressing

```text
40% pressures percentile
35% high-pressures percentile
25% counterpressures percentile
```

### Possession Security

```text
60% pass-completion percentile
20% recoveries percentile
20% interceptions percentile
```

The final label is retained in the dashboard for model consistency; conceptually it captures a mixture of **ball security and ball-winning contribution**.

---

## 10. Squad-gap model

A club is not given one overall weakness score. Instead, analysis occurs at the grain:

> **Club × Position Group**

For example, Manchester City's defensive midfielders can have different weaknesses from Manchester City's wingers.

For each club-position group:

1. Average the five attribute scores of eligible players.
2. Calculate the league-wide average for that same position group.
3. Measure only below-benchmark gaps:

```text
gap = max(league_position_benchmark - club_position_score, 0)
```

4. Normalise the five positive gaps so they sum to `1`.

These become the recruitment weights.

A large finishing gap therefore makes finishing more important when evaluating candidates for that particular target club and position.

---

## 11. Sporting-fit score

Candidate rules:

- Candidate must belong to the **same position group** as the target requirement.
- Candidate must currently play for a **different club**.
- Candidate must have passed the `900`-minute eligibility threshold.

Sporting fit is the weighted sum:

```text
fit =
    finishing_score  * finishing_need_weight
  + creativity_score * creativity_need_weight
  + progression_score * progression_need_weight
  + pressing_score * pressing_need_weight
  + security_score * security_need_weight
```

Candidates are ranked separately within every target **club × position group** using `DENSE_RANK()`.

If a club-position group is at or above the league benchmark in every attribute, all five need weights would otherwise be null. In that case, the model falls back to equal `20%` weights so a shortlist can still be produced.

---

## 12. Data-quality checks

### Official goals vs player goals

The match table contains `437` official goals. Shot events produced `420` player-attributed goals.

The `17`-goal difference corresponds to own goals, which StatsBomb records separately rather than crediting as normal shot-event goals to an opposing player.

The model therefore **does not artificially assign own goals to recruitment candidates**.

### Fact-table grain

`UNIQUE(match_id, player_key)` is enforced in the player-match fact table.

This protects season aggregation from accidental duplicate appearances.

### Playing time

Starter counts and duration ranges were checked after replacing the faulty lineup-timing approach with event-based reconstruction.

---

## 13. Power BI model

Power BI imports three clean PostgreSQL reporting views:

- `analytics.v_player_profiles`
- `analytics.v_squad_needs_report`
- `analytics.v_recruitment_candidates`

Two relationships support the report:

```text
v_player_profiles[player_key]
          1
          |
          *
v_recruitment_candidates[player_key]
```

and a composite `club_position_key` created in Power Query:

```text
v_squad_needs_report[club_position_key]
          1
          |
          *
v_recruitment_candidates[club_position_key]
```

The composite key ensures that a club's winger requirements filter its winger candidates rather than all candidates for the club.

---

## 14. Limitations

This is a decision-support portfolio model, not a complete professional scouting system.

Important limitations include:

- No verified historical market-value, salary, contract or transfer-fee layer.
- No age constraint in the current model.
- One season of performance data.
- Event-based primary-position classification simplifies hybrid tactical roles.
- Attribute weights are transparent modelling choices, not learned causal weights.
- Straight-line progression ignores defensive shape and possession context.
- Percentiles can be less stable in position groups with small eligible samples.
- No injury, availability, homegrown-status or registration constraints.
- Sporting fit measures statistical profile compatibility; it does not predict transfer success.

These limitations are intentionally stated to keep the analysis defensible.

---

## 15. Possible extensions

- Add age / date of birth from a reliable external roster source.
- Add verified contract and market-value information.
- Incorporate role-specific models within broad positions.
- Back-test recommendations on later seasons.
- Add uncertainty / confidence intervals around small samples.
- Compare team style using possession, pressure and transition profiles.
- Build similarity search for replacement-player analysis.
