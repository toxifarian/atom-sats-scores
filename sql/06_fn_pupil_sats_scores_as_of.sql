-- 06_fn_pupil_sats_scores_as_of.sql
-- Point-in-time access: each pupil's score per subject exactly as it stood at a given moment.
--
-- Usage:
--   SELECT * FROM `atom-analytics-candidates.paul_martin.fn_pupil_sats_scores_as_of`(TIMESTAMP '2025-03-01');

CREATE OR REPLACE TABLE FUNCTION `atom-analytics-candidates.paul_martin.fn_pupil_sats_scores_as_of`(as_of TIMESTAMP)
AS
SELECT *
FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
WHERE valid_from <= as_of
  AND (valid_to IS NULL OR valid_to > as_of);
