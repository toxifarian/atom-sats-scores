-- 01_staging.sql
-- Staging layer: one view per raw table. Light-touch only: select and type columns,
-- standardise names, and de-duplicate on the natural key so downstream models can
-- rely on one row per key. No business filtering happens here.

-- Pupils: one row per pupil.
CREATE OR REPLACE VIEW `atom-analytics-candidates.paul_martin.stg_pupils` AS
SELECT
  pupil_id,
  COALESCE(is_deleted, FALSE) AS is_deleted
FROM `atom-analytics-candidates.de_raw.pupils`
WHERE pupil_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY pupil_id ORDER BY is_deleted DESC) = 1;

-- Course hierarchy: one row per question, plus the SATs paper it maps to.
-- English -> KS2 reading (confirmed with Atom); Maths -> KS2 maths; everything else is out of SATs scope.
CREATE OR REPLACE VIEW `atom-analytics-candidates.paul_martin.stg_course_hierarchy` AS
SELECT
  question_id,
  atom_id,
  subtopic_id,
  topic_id,
  subject_id,
  subject_name,
  CASE subject_name
    WHEN 'Maths'   THEN 'maths'
    WHEN 'English' THEN 'reading'
  END AS sats_paper
FROM `atom-analytics-candidates.de_raw.course_hierarchy`
WHERE question_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY question_id ORDER BY subject_id, subtopic_id) = 1;

-- Assessment sittings: one row per sitting (session).
CREATE OR REPLACE VIEW `atom-analytics-candidates.paul_martin.stg_assessment_sittings` AS
SELECT
  session_id,
  pupil_id,
  assessment_id,
  session_type,
  style,
  year_group_at_sitting,
  total_questions,
  COALESCE(is_complete, FALSE) AS is_complete,
  COALESCE(is_deleted, FALSE)  AS is_deleted,
  started_at,
  finished_at
FROM `atom-analytics-candidates.de_raw.assessment_sittings`
WHERE session_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY finished_at DESC, started_at DESC) = 1;

-- Responses: one row per response.
-- responses.session_type is dropped: it is 'MOCK_TEST' on every row and contradicts the
-- sittings table, which is treated as the source of truth (see DECISIONS.md #2).
CREATE OR REPLACE VIEW `atom-analytics-candidates.paul_martin.stg_responses` AS
SELECT
  response_id,
  pupil_id,
  session_id,
  question_id,
  COALESCE(is_correct, FALSE)    AS is_correct,
  COALESCE(is_no_attempt, FALSE) AS is_no_attempt,
  seconds_taken,
  question_number,
  answered_at
FROM `atom-analytics-candidates.de_raw.responses`
WHERE response_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY response_id ORDER BY answered_at DESC) = 1;
