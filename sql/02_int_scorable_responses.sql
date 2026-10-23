-- 02_int_scorable_responses.sql
-- Intermediate layer: every response that counts towards a SATs score, enriched with its
-- subject, SATs paper and sitting context.
--
-- Grain: one row per pupil, per sitting, per question (the final answer given).
--
-- Rules applied (see DECISIONS.md):
--   - the sitting must exist, be complete, not be deleted, and not be a survey
--   - the pupil must not be deleted
--   - the question must map to a SATs paper (Maths or English)
--   - if a question was answered more than once in the same sitting, the latest answer counts
--   - "no attempt" scores as incorrect
--
-- Partitioned by answer date and clustered by pupil and paper: this is the table that
-- grows to 100m+ rows, and both keys are what downstream models filter and group on.
-- At production volume this would be loaded incrementally with MERGE (see README).

CREATE OR REPLACE TABLE `atom-analytics-candidates.paul_martin.int_scorable_responses`
PARTITION BY DATE(answered_at)
CLUSTER BY pupil_id, sats_paper
AS
SELECT
  r.response_id,
  r.pupil_id,
  r.session_id,
  s.assessment_id,
  s.session_type,
  s.year_group_at_sitting,
  s.finished_at               AS sitting_finished_at,
  r.question_id,
  h.subject_id,
  h.subject_name,
  h.sats_paper,
  r.is_correct AND NOT r.is_no_attempt AS is_correct,
  r.is_no_attempt,
  r.answered_at
FROM `atom-analytics-candidates.paul_martin.stg_responses` AS r
JOIN `atom-analytics-candidates.paul_martin.stg_assessment_sittings` AS s
  ON r.session_id = s.session_id
JOIN `atom-analytics-candidates.paul_martin.stg_pupils` AS p
  ON r.pupil_id = p.pupil_id
JOIN `atom-analytics-candidates.paul_martin.stg_course_hierarchy` AS h
  ON r.question_id = h.question_id
WHERE s.is_complete
  AND NOT s.is_deleted
  AND COALESCE(s.style, '') != 'survey'
  AND NOT p.is_deleted
  AND h.sats_paper IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY r.session_id, r.question_id
  ORDER BY r.answered_at DESC, r.response_id DESC
) = 1;
