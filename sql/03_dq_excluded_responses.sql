-- 03_dq_excluded_responses.sql
-- Data quality: every response NOT used for scoring, with the reason it was excluded.
-- Lets reviewers and upstream owners see exactly what was dropped and why.
-- One row per response; where several reasons apply, the first in the CASE order is reported.

CREATE OR REPLACE TABLE `atom-analytics-candidates.paul_martin.dq_excluded_responses`
CLUSTER BY exclusion_reason
AS
SELECT
  r.response_id,
  r.pupil_id,
  r.session_id,
  r.question_id,
  h.subject_name,
  r.answered_at,
  CASE
    WHEN s.session_id IS NULL     THEN 'orphan_session'
    WHEN s.is_deleted             THEN 'deleted_sitting'
    WHEN NOT s.is_complete        THEN 'incomplete_sitting'
    WHEN s.style = 'survey'       THEN 'survey_sitting'
    WHEN p.pupil_id IS NULL       THEN 'orphan_pupil'
    WHEN p.is_deleted             THEN 'deleted_pupil'
    WHEN h.question_id IS NULL    THEN 'orphan_question'
    WHEN h.sats_paper IS NULL     THEN 'non_sats_subject'
    ELSE 'superseded_repeat_answer'
  END AS exclusion_reason
FROM `atom-analytics-candidates.paul_martin.stg_responses` AS r
LEFT JOIN `atom-analytics-candidates.paul_martin.stg_assessment_sittings` AS s
  ON r.session_id = s.session_id
LEFT JOIN `atom-analytics-candidates.paul_martin.stg_pupils` AS p
  ON r.pupil_id = p.pupil_id
LEFT JOIN `atom-analytics-candidates.paul_martin.stg_course_hierarchy` AS h
  ON r.question_id = h.question_id
WHERE r.response_id NOT IN (
  SELECT response_id FROM `atom-analytics-candidates.paul_martin.int_scorable_responses`
);
