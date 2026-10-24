# Atom Learning || SATs scores

Produces a KS2 SATs-equivalent scaled score (80–120) for every pupil in every SATs subject, as a set of layered, re-runnable BigQuery models with point-in-time history. Everything is materialised in `atom-analytics-candidates.paul_martin`.

## Results at a glance

| | |
|---|---|
| Raw responses | 63,707 |
| Responses used for scoring | 44,366 |
| Responses excluded (every one explained) | 19,341 |
| Score history rows (point-in-time) | 1,719 |
| Current output rows (242 pupils × 2 subjects) | 484 |
| Pupils with a score | English 153, Maths 151 |
| Average current score | English 101.1, Maths 100.9 |
| Meeting the expected standard (100+) | English 60.1%, Maths 56.3% |

Pupils with no Maths or English evidence still get a row in the output, with `has_score = FALSE`, so nobody silently disappears.

Sanity check: nationally, about three quarters of Year 6 pupils meet the expected standard. These figures are lower, which is plausible because the data covers Years 1–6, and younger pupils are being scored against an end-of-KS2 scale.

## How to run

Run the files in `sql/` in numerical order (00–07) in the BigQuery console. Every model uses `CREATE OR REPLACE` with deterministic logic, so the pipeline can be re-run at any time. `07_tests.sql` must pass with no failed assertions.

## How the pieces fit together

```
de_raw (source)          staging (views)             intermediate                     marts
──────────────           ───────────────             ────────────                     ─────
pupils               ─►  stg_pupils              ─┐
course_hierarchy     ─►  stg_course_hierarchy    ─┤
assessment_sittings  ─►  stg_assessment_sittings ─┼─► int_scorable_responses ──► fct_pupil_sats_score_history ──► pupil_sats_scores_current
responses            ─►  stg_responses           ─┘   dq_excluded_responses       fn_pupil_sats_scores_as_of(ts)
seed_sats_conversion (official GOV.UK 2025 tables) ─────────────────────────────┘
```

| File | Object | Grain | Purpose |
|---|---|---|---|
| `00_seed_sats_conversion.sql` | `seed_sats_conversion` | paper × raw mark | Official 2025 KS2 raw-to-scaled conversion tables for maths, reading and GPS |
| `01_staging.sql` | `stg_*` views | one row per source key | Typing, renaming, null handling and de-duplication on natural keys. Maps subjects to SATs papers. No business filtering |
| `02_int_scorable_responses.sql` | `int_scorable_responses` | pupil × sitting × question | The responses that count, with subject and sitting context. Partitioned by answer date and clustered by pupil and paper |
| `03_dq_excluded_responses.sql` | `dq_excluded_responses` | one row per excluded response | Every response not used, with a reason code. Scored plus excluded always equals staged (this is tested) |
| `04_fct_pupil_sats_score_history.sql` | `fct_pupil_sats_score_history` | pupil × paper × sitting | Point-in-time score history with `valid_from` and `valid_to` |
| `05_pupil_sats_scores_current.sql` | `pupil_sats_scores_current` | pupil × subject | Application-ready current score. Primary key `(pupil_id, subject_name)` |
| `06_fn_pupil_sats_scores_as_of.sql` | `fn_pupil_sats_scores_as_of` | table function | Scores as they stood at any timestamp |
| `07_tests.sql` | assertions | | Uniqueness, score range, one current row per key, completeness and re-runnability |
| `08_summary_metrics.sql` | query | | The headline figures quoted in this README |

## Step 1: How a score is calculated

1. Take the pupil's scorable responses in a subject from sittings in their **current year group**. English maps to the KS2 reading paper (confirmed with Atom) and Maths to the KS2 maths paper.
2. Percentage correct × the paper's maximum raw mark (reading 50, maths 110) = equivalent raw mark, rounded.
3. Look up the equivalent raw mark in the **official 2025 GOV.UK conversion table**. The real tables are not linear, so a lookup is more faithful than scaling the percentage straight onto 80–120.
4. Raw marks 0–2 have no official scaled score. They are floored to 80 and flagged with `is_below_official_minimum`. No current scores needed this.

The full reasoning behind each rule is in [DECISIONS.md](DECISIONS.md).

## Step 2: Design for longevity

**Layering.** The layers follow dbt conventions (staging, intermediate, marts), so a colleague can add a new question without touching the scoring logic. For example, they could build a topic-level score from `int_scorable_responses`, which already carries the full subject hierarchy. The SQL ports directly to dbt models, with the `ASSERT`s becoming dbt tests.

**Re-runnable.** No model depends on run time, and every window function has a deterministic tie-breaker. I ran the full pipeline twice and fingerprinted the history table each time:

| Run | Fingerprint (`BIT_XOR` of row hashes) | Rows |
|---|---|---|
| 1 | `-6722694541268686623` | 1,719 |
| 2 | `-6722694541268686623` | 1,719 |

**Point-in-time.** `fct_pupil_sats_score_history` is a type 2 history table. Each row is a pupil's score once a sitting **finished**, valid from `valid_from` until the next sitting's finish (`valid_to`), so a half-finished test never changes a score. Recompute any moment with:

```sql
SELECT * FROM `atom-analytics-candidates.paul_martin.fn_pupil_sats_scores_as_of`(TIMESTAMP '2025-03-01');
```

Because scores only change when a sitting completes, the history is compact (1,719 rows from 44,366 responses) and every change can be traced to the sitting that caused it (`triggering_session_id`).

**Production volumes (responses growing by 100m+).**

- `int_scorable_responses` is partitioned by `DATE(answered_at)` and clustered by `pupil_id, sats_paper`, so scans and joins touch only what they need.
- In production, I would load it **incrementally** rather than rebuild it. Each run merges only new or changed responses from a lookback window, keyed on `(session_id, question_id)`:

  ```sql
  MERGE `paul_martin.int_scorable_responses` AS t
  USING (/* the 02 SELECT, filtered to answered_at >= last high-water mark minus a lookback window */) AS s
  ON t.session_id = s.session_id AND t.question_id = s.question_id
  WHEN MATCHED AND s.answered_at > t.answered_at THEN UPDATE SET ...
  WHEN NOT MATCHED THEN INSERT ROW
  ```

- The history table is then rebuilt only for the `(pupil_id, sats_paper)` pairs touched in that run, not the whole population.
- Orchestration: Airflow, or a dbt incremental model, running after each source load, with the tests as a gate before the output is published.

**Migrating to the application database.** `pupil_sats_scores_current` is flat, with no nested or repeated fields. It uses plain types (STRING, INT64, FLOAT64, BOOL, TIMESTAMP), has a clear primary key of `(pupil_id, subject_name)`, and has one row per key, guaranteed by a test. It maps one-to-one onto a relational table and can be loaded by upsert on that key. Flags such as `has_score`, `is_low_evidence` and `meets_expected_standard` let the application decide how to display each score without re-deriving the rules.

## Data quality

The main findings were orphaned responses with no sitting (1,433), a `session_type` column on responses that is wrong on every row, repeat answers to the same question within a sitting (2,082 cases), incomplete and survey sittings, and impossible year groups. All are documented with their counts and handling in [DECISIONS.md](DECISIONS.md). Excluded responses by reason:

| Reason | Responses |
|---|---|
| `non_sats_subject` (Science, Verbal and Non-Verbal Reasoning, Screeners) | 11,783 |
| `survey_sitting` (Wellbeing) | 3,936 |
| `superseded_repeat_answer` | 2,158 |
| `orphan_session` | 1,433 |
| `incomplete_sitting` | 31 |

The orphaned sessions are worth raising upstream: 1,196 of them are Maths or English answers that would otherwise count.

## Step 3: Predicting GCSE results from primary-school work

**Data.** The essential input is the same pupils tracked from primary school to their actual GCSE results. Without known outcomes, there is nothing to learn from or validate against. Inside Atom, that could come from pupils who continue from Quest or Atom Home into Home Senior and report their GCSE grades. Externally, it could come from linked national data. The DfE's own KS2-to-KS4 transition matrices, published with Progress 8, give a public baseline for how KS2 scores translate into GCSE grades.

**Features.** The point-in-time history built here is the right foundation. Each pupil's KS2-equivalent scores per subject, taken *as they stood* at a fixed point such as the end of Year 6, avoid leaking later information into the training data. I would add the trend over time (trajectory rather than a single snapshot), topic-level strengths and weaknesses from the hierarchy, engagement (how much and how consistently a pupil practises), and school context.

**Approach.** Start simple and explainable: a transition matrix, or an ordinal regression, from KS2 score band to GCSE grade per subject, calibrated against known outcomes. Only add complexity once that baseline is understood and its errors are measured. Teachers need to trust and act on the output, so calibrated probabilities ("a 70% chance of grade 5 or above") are more useful than a single predicted grade.

**Assumptions and risks.**

- The KS2-to-GCSE relationship is assumed to be stable between cohorts. That needs monitoring, because the curriculum, the exams and grading all change.
- Atom's assessments are assumed to measure the same thing as the real SATs.
- Selection bias is a real risk. Pupils who keep using Atom for five years are not a random sample.
- Long time gaps mean intervening factors, such as changing school, can't be observed.
- This is children's data, so it needs a clear lawful basis, minimisation, pseudonymisation in modelling datasets, and care that predictions are used to direct support, never to label pupils.

## What I would do next

- **Incremental loading:** convert `int_scorable_responses` and the history table to incremental MERGE loads, as above, and move the project into dbt with these assertions as dbt tests.
- **Question difficulty:** weight questions by difficulty, for example using each question's national facility rate. This would make scores comparable across easier and harder assessments.
- **Reading vs GPS:** split English into reading and GPS once the topic hierarchy has names, and score each against its own table.
- **Confidence:** replace the simple 20-question low-evidence flag with a confidence interval around each score.
- **Upstream fixes:** take the orphaned sessions and the incorrect `responses.session_type` to the owners of the source data.

