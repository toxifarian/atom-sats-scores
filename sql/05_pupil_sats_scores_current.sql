-- 05_pupil_sats_scores_current.sql
-- Application-ready output: one row per pupil per SATs subject, with the latest score.
--
-- Primary key: (pupil_id, subject_name). Flat, typed columns only, so it maps directly onto
-- a relational table in the application database.
--
-- Every active pupil gets a row for every SATs subject. Where a pupil has no scorable
-- evidence in a subject, sats_scaled_score is NULL and has_score is FALSE, rather than the
-- row being silently missing.

CREATE OR REPLACE TABLE `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`
CLUSTER BY pupil_id
AS
WITH subjects AS (
  SELECT 'Maths' AS subject_name, 'maths' AS sats_paper UNION ALL
  SELECT 'English', 'reading'
)
SELECT
  p.pupil_id,
  sub.subject_name,
  sub.sats_paper,
  h.sats_scaled_score IS NOT NULL          AS has_score,
  h.sats_scaled_score,
  h.sats_scaled_score >= 100               AS meets_expected_standard,
  h.sats_scaled_score >= 110               AS meets_high_standard,
  h.pct_correct,
  h.questions_answered,
  h.questions_correct,
  h.sittings_counted,
  h.year_group,
  h.is_low_evidence,
  h.is_below_official_minimum,
  h.valid_from                             AS score_as_of,
  h.score_history_id
FROM `atom-analytics-candidates.paul_martin.stg_pupils` AS p
CROSS JOIN subjects AS sub
LEFT JOIN `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history` AS h
  ON  h.pupil_id   = p.pupil_id
  AND h.sats_paper = sub.sats_paper
  AND h.is_current
WHERE NOT p.is_deleted;
