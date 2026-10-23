-- Row counts, key uniqueness, nulls, orphans and timestamp sanity across the four raw tables.
WITH
r AS (SELECT * FROM `atom-analytics-candidates.de_raw.responses`),
s AS (SELECT * FROM `atom-analytics-candidates.de_raw.assessment_sittings`),
p AS (SELECT * FROM `atom-analytics-candidates.de_raw.pupils`),
h AS (SELECT * FROM `atom-analytics-candidates.de_raw.course_hierarchy`),
resp_per_session AS (
  SELECT session_id, COUNT(*) AS n_responses FROM r GROUP BY session_id
)

SELECT 'responses: rows' AS check_name, COUNT(*) AS value FROM r
UNION ALL SELECT 'responses: distinct response_id', COUNT(DISTINCT response_id) FROM r
UNION ALL SELECT 'responses: null response_id', COUNTIF(response_id IS NULL) FROM r
UNION ALL SELECT 'responses: exact duplicate rows', COUNT(*) - COUNT(DISTINCT TO_JSON_STRING(r)) FROM r
UNION ALL SELECT 'responses: null is_correct', COUNTIF(is_correct IS NULL) FROM r
UNION ALL SELECT 'responses: is_no_attempt = true', COUNTIF(is_no_attempt) FROM r
UNION ALL SELECT 'responses: correct AND no_attempt', COUNTIF(is_correct AND is_no_attempt) FROM r
UNION ALL SELECT 'responses: null answered_at', COUNTIF(answered_at IS NULL) FROM r
UNION ALL SELECT 'responses: answered_at in future', COUNTIF(answered_at > CURRENT_TIMESTAMP()) FROM r
UNION ALL SELECT 'responses: null session_id', COUNTIF(session_id IS NULL) FROM r
UNION ALL SELECT 'responses: session not in sittings', COUNT(*) FROM r LEFT JOIN s ON r.session_id = s.session_id WHERE s.session_id IS NULL
UNION ALL SELECT 'responses: question not in hierarchy', COUNT(*) FROM r LEFT JOIN h ON r.question_id = h.question_id WHERE h.question_id IS NULL
UNION ALL SELECT 'responses: pupil not in pupils', COUNT(*) FROM r LEFT JOIN p ON r.pupil_id = p.pupil_id WHERE p.pupil_id IS NULL
UNION ALL SELECT 'responses: pupil_id differs from sitting', COUNTIF(r.pupil_id != s.pupil_id) FROM r JOIN s ON r.session_id = s.session_id
UNION ALL SELECT 'responses: session_type differs from sitting', COUNTIF(r.session_type != s.session_type) FROM r JOIN s ON r.session_id = s.session_id
UNION ALL SELECT 'responses: answered outside sitting window', COUNTIF(r.answered_at < s.started_at OR r.answered_at > s.finished_at) FROM r JOIN s ON r.session_id = s.session_id

UNION ALL SELECT 'sittings: rows', COUNT(*) FROM s
UNION ALL SELECT 'sittings: distinct session_id', COUNT(DISTINCT session_id) FROM s
UNION ALL SELECT 'sittings: is_deleted = true', COUNTIF(is_deleted) FROM s
UNION ALL SELECT 'sittings: is_complete = false', COUNTIF(NOT is_complete) FROM s
UNION ALL SELECT 'sittings: is_complete null', COUNTIF(is_complete IS NULL) FROM s
UNION ALL SELECT 'sittings: null finished_at', COUNTIF(finished_at IS NULL) FROM s
UNION ALL SELECT 'sittings: finished before started', COUNTIF(finished_at < started_at) FROM s
UNION ALL SELECT 'sittings: response count != total_questions', COUNTIF(rp.n_responses != s.total_questions) FROM s JOIN resp_per_session rp ON s.session_id = rp.session_id
UNION ALL SELECT 'sittings: with no responses', COUNT(*) FROM s LEFT JOIN resp_per_session rp ON s.session_id = rp.session_id WHERE rp.session_id IS NULL

UNION ALL SELECT 'pupils: rows', COUNT(*) FROM p
UNION ALL SELECT 'pupils: distinct pupil_id', COUNT(DISTINCT pupil_id) FROM p
UNION ALL SELECT 'pupils: is_deleted = true', COUNTIF(is_deleted) FROM p

UNION ALL SELECT 'hierarchy: rows', COUNT(*) FROM h
UNION ALL SELECT 'hierarchy: distinct question_id', COUNT(DISTINCT question_id) FROM h
UNION ALL SELECT 'hierarchy: null subject_name', COUNTIF(subject_name IS NULL) FROM h;
