# Decisions and data quality log

Findings from profiling `de_raw`, and the decision taken for each. Profiling queries are in `sql/profiling/`.

## Data quality findings

| # | Finding | Evidence | Decision |
|---|---|---|---|
| 1 | `responses.response_id` is unique and non-null | 63,707 rows, 63,707 distinct, 0 nulls | Use as the primary key of the response grain |
| 2 | `responses.session_type` is always `MOCK_TEST`, which contradicts `assessment_sittings.session_type` | 62,274 of 62,274 joined rows differ | Treat the sittings table as the source of truth; ignore the responses copy |
| 3 | Responses whose `session_id` is not in `assessment_sittings` | 1,433 rows (English 889, Maths 307, Screeners 141, Wellbeing 96) | Exclude from scoring, because completion and assessment type can't be verified. Keep them in a quarantine table and flag them as an upstream issue |
| 4 | Responses timestamped outside their sitting's start/finish window | 1,608 rows, all within 1 minute | Clock or rounding noise; keep |
| 5 | Incomplete sittings | 13 sittings: `is_complete = false`, which are exactly the 13 with null `finished_at` | Exclude; an abandoned test is not a valid measure |
| 6 | Sittings with no responses | 79 | No effect on scores; ignore |
| 7 | Sittings with more responses than `total_questions` | 747 sittings (10 have fewer, 1,673 equal) | Investigate repeated answers to the same question in one sitting (see #8) |
| 8 | Repeated answers to the same question within a sitting | _pending: query G_ | _pending_ |
| 9 | "No attempt" responses | 3,279 rows | Count as incorrect, as an unanswered SATs question scores 0 |
| 10 | Survey sittings | 125 sittings (Wellbeing) | Exclude; not an assessment |
| 11 | Year groups 11, 14 and 15 on some sittings | 25 sittings | None are Maths or English, so they don't affect SATs scores. Logged as a source anomaly |
| 12 | No deleted pupils or sittings, no null correctness, no orphaned questions or pupils | 0 rows each | Filters for these are still applied so the model stays correct as data grows |

## Scoring decisions

- **Subjects in scope.** KS2 SATs cover Reading, Grammar/Punctuation/Spelling (GPS) and Maths. Only `Maths` and `English` map to them. Science (not a scaled-score SATs test), Verbal and Non-Verbal Reasoning, Screeners and Wellbeing are out of scope.
- **English mapping.** The hierarchy holds IDs only, so English can't be split into Reading and GPS. English is scored against the KS2 Reading table. _Confirm with Atom._
- **Method.** Percentage correct × the paper's maximum raw mark gives an equivalent raw mark (rounded), which is looked up in the official 2025 GOV.UK conversion table (`seed_sats_conversion`).
- **Below the official minimum.** Raw marks 0–2 have no official scaled score. They are floored to 80 and flagged, because the brief asks for a score for every pupil.
- **Year groups.** Pupils in Years 1–6 all receive a SATs-equivalent score: "what this performance would convert to on the KS2 scale". This is a projection for younger pupils, not a prediction.
- **Equal weighting.** Every question counts equally, and question difficulty is not modelled.
