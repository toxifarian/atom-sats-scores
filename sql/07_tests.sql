-- 07_tests.sql
-- Data tests. Each ASSERT fails the script with a clear message if a rule is broken.
-- Run after 00-06.

ASSERT (
  SELECT COUNT(*) FROM (
    SELECT session_id, question_id FROM `atom-analytics-candidates.paul_martin.int_scorable_responses`
    GROUP BY 1, 2 HAVING COUNT(*) > 1)
) = 0 AS 'int_scorable_responses: more than one answer per sitting and question';

ASSERT (
  SELECT COUNT(*) - COUNT(DISTINCT score_history_id)
  FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
) = 0 AS 'fct_pupil_sats_score_history: score_history_id is not unique';

ASSERT (
  SELECT COUNTIF(sats_scaled_score NOT BETWEEN 80 AND 120 OR sats_scaled_score IS NULL)
  FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
) = 0 AS 'fct_pupil_sats_score_history: score missing or outside 80-120';

ASSERT (
  SELECT COUNT(*) FROM (
    SELECT pupil_id, sats_paper FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
    WHERE is_current GROUP BY 1, 2 HAVING COUNT(*) > 1)
) = 0 AS 'fct_pupil_sats_score_history: more than one current score per pupil and paper';

ASSERT (
  SELECT COUNTIF(valid_to < valid_from)
  FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
) = 0 AS 'fct_pupil_sats_score_history: valid_to before valid_from';

ASSERT (
  SELECT COUNT(*) - COUNT(DISTINCT CONCAT(pupil_id, '|', subject_name))
  FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`
) = 0 AS 'pupil_sats_scores_current: (pupil_id, subject_name) is not unique';

ASSERT (
  (SELECT COUNT(*) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`)
  = 2 * (SELECT COUNT(*) FROM `atom-analytics-candidates.paul_martin.stg_pupils` WHERE NOT is_deleted)
) AS 'pupil_sats_scores_current: expected one row per active pupil per subject';

ASSERT (
  (SELECT COUNT(*) FROM `atom-analytics-candidates.paul_martin.int_scorable_responses`)
  + (SELECT COUNT(*) FROM `atom-analytics-candidates.paul_martin.dq_excluded_responses`)
  = (SELECT COUNT(*) FROM `atom-analytics-candidates.paul_martin.stg_responses`)
) AS 'every staged response is either scored or explained in dq_excluded_responses';

-- Re-runnability: record this fingerprint, re-run 00-06, and run this query again.
-- The value must be identical.
SELECT BIT_XOR(FARM_FINGERPRINT(TO_JSON_STRING(t))) AS history_fingerprint, COUNT(*) AS n_rows
FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history` AS t;
