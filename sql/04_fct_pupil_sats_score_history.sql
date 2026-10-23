-- 04_fct_pupil_sats_score_history.sql
-- Point-in-time score history (type 2 slowly changing dimension).
--
-- Grain: one row per pupil, per SATs paper, per completed sitting that included that paper.
-- Each row is the pupil's score as it stood once that sitting finished, valid from
-- valid_from until the next sitting (valid_to), or open-ended if it is the current score.
--
-- Scoring window: cumulative within the pupil's year group. A Year 6 score uses only
-- Year 6 sittings, so it reflects current attainment rather than being dragged down by
-- work from earlier years, and it changes only when a new sitting completes, which keeps
-- the history clean and auditable.
--
-- Score: percentage correct x the paper's maximum raw mark = equivalent raw mark, which
-- is looked up in the official 2025 KS2 conversion table (seed_sats_conversion).

CREATE OR REPLACE TABLE `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
CLUSTER BY pupil_id, sats_paper
AS
WITH

per_sitting AS (
  SELECT
    pupil_id,
    sats_paper,
    subject_name,
    session_id,
    year_group_at_sitting,
    sitting_finished_at,
    COUNT(*)            AS questions_answered,
    COUNTIF(is_correct) AS questions_correct
  FROM `atom-analytics-candidates.paul_martin.int_scorable_responses`
  GROUP BY 1, 2, 3, 4, 5, 6
),

cumulative AS (
  SELECT
    *,
    SUM(questions_answered) OVER w_year AS cum_questions_answered,
    SUM(questions_correct)  OVER w_year AS cum_questions_correct,
    COUNT(*)                OVER w_year AS cum_sittings
  FROM per_sitting
  WINDOW w_year AS (
    PARTITION BY pupil_id, sats_paper, year_group_at_sitting
    ORDER BY sitting_finished_at, session_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )
),

papers AS (
  SELECT DISTINCT sats_paper, max_raw_mark
  FROM `atom-analytics-candidates.paul_martin.seed_sats_conversion`
),

scored AS (
  SELECT
    c.*,
    SAFE_DIVIDE(c.cum_questions_correct, c.cum_questions_answered) AS pct_correct,
    CAST(ROUND(SAFE_DIVIDE(c.cum_questions_correct, c.cum_questions_answered) * p.max_raw_mark) AS INT64)
      AS equivalent_raw_mark,
    p.max_raw_mark
  FROM cumulative AS c
  JOIN papers AS p USING (sats_paper)
)

SELECT
  CONCAT(s.pupil_id, '|', s.sats_paper, '|', s.session_id) AS score_history_id,
  s.pupil_id,
  s.subject_name,
  s.sats_paper,
  s.year_group_at_sitting                                  AS year_group,
  s.session_id                                             AS triggering_session_id,
  s.cum_sittings                                           AS sittings_counted,
  s.cum_questions_answered                                 AS questions_answered,
  s.cum_questions_correct                                  AS questions_correct,
  ROUND(s.pct_correct, 4)                                  AS pct_correct,
  s.equivalent_raw_mark,
  s.max_raw_mark,
  conv.scaled_score                                        AS sats_scaled_score,
  conv.is_below_official_minimum,
  s.cum_questions_answered < 20                            AS is_low_evidence,
  s.sitting_finished_at                                    AS valid_from,
  LEAD(s.sitting_finished_at) OVER w_pupil                 AS valid_to,
  LEAD(s.sitting_finished_at) OVER w_pupil IS NULL         AS is_current
FROM scored AS s
JOIN `atom-analytics-candidates.paul_martin.seed_sats_conversion` AS conv
  ON  conv.sats_paper = s.sats_paper
  AND conv.raw_mark   = s.equivalent_raw_mark
WINDOW w_pupil AS (
  PARTITION BY s.pupil_id, s.sats_paper
  ORDER BY s.sitting_finished_at, s.session_id
);
