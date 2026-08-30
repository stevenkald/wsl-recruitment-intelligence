# Power BI Model Notes

## Imported reporting views

- `analytics v_recruitment_candidates`
- `analytics v_squad_needs_report`
- `analytics v_player_profiles`

## Power Query composite key

Add `club_position_key` to the candidate view:

```powerquery
Text.From([target_team_key]) & "|" & [position_group]
```

Add `club_position_key` to the squad-needs view:

```powerquery
Text.From([team_key]) & "|" & [position_group]
```

## Relationships

1. `v_recruitment_candidates[player_key]` many-to-one → `v_player_profiles[player_key]`
2. `v_recruitment_candidates[club_position_key]` many-to-one → `v_squad_needs_report[club_position_key]`

Both relationships are active with single-direction filtering.

## DAX measures

```DAX
Candidate Count =
DISTINCTCOUNT(
    'analytics v_recruitment_candidates'[player_key]
)
```

```DAX
Best Candidate =
VAR BestRow =
    TOPN(
        1,
        'analytics v_recruitment_candidates',
        'analytics v_recruitment_candidates'[sporting_fit_score],
        DESC,
        'analytics v_recruitment_candidates'[player_name],
        ASC
    )
RETURN
    MAXX(
        BestRow,
        'analytics v_recruitment_candidates'[player_name]
    )
```

```DAX
Best Fit Score =
MAX(
    'analytics v_recruitment_candidates'[sporting_fit_score]
)
```

```DAX
Recruitment Context =
VAR Club =
    SELECTEDVALUE(
        'analytics v_squad_needs_report'[team_name],
        "Select a club"
    )
VAR Position =
    SELECTEDVALUE(
        'analytics v_squad_needs_report'[position_group],
        "Select a position"
    )
RETURN
    Club & " — " & Position
```

```DAX
Progression Need % =
COALESCE(
    MAX('analytics v_squad_needs_report'[progression_weight]),
    0.20
)
```

```DAX
Pressing Need % =
COALESCE(
    MAX('analytics v_squad_needs_report'[pressing_weight]),
    0.20
)
```

```DAX
Creativity Need % =
COALESCE(
    MAX('analytics v_squad_needs_report'[creativity_weight]),
    0.20
)
```

```DAX
Finishing Need % =
COALESCE(
    MAX('analytics v_squad_needs_report'[finishing_weight]),
    0.20
)
```

```DAX
Security Need % =
COALESCE(
    MAX('analytics v_squad_needs_report'[security_weight]),
    0.20
)
```

For display, format the five need measures as **Percentage** rather than decimal values.

## Recruitment Overview page

The page follows a decision-making sequence:

1. Select target club.
2. Select position.
3. Inspect best candidate, fit score and candidate count.
4. See the five recruitment-priority weights.
5. Review the ranked top-10 shortlist with selected per-90 performance indicators.

The table uses a visual-level filter of `sporting_fit_rank <= 10`.
