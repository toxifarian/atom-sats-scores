-- Follow-up checks on orphans, timestamp drift, response counts, subject/style mix and year groups.
WITH
r AS (SELECT * FROM `atom-analytics-candidates.de_raw.responses`),
s AS (SELECT * FROM `atom-analytics-candidates.de_raw.assessment_sittings`),
h AS (SELECT * FROM `atom-analytics-candidates.de_raw.course_hierarchy`)

SELECT 'A orphan responses by subject' AS check_name, h.subject_name AS detail, COUNT(*) AS n
FROM r LEFT JOIN s ON r.session_id = s.session_id JOIN h ON r.question_id = h.question_id
WHERE s.session_id IS NULL GROUP BY 2

UNION ALL
SELECT 'B outside window, minutes bucket',
  CASE WHEN m <= 1 THEN '<=1' WHEN m <= 10 THEN '1-10' WHEN m <= 60 THEN '10-60' WHEN m <= 1440 THEN '1h-1d' ELSE '>1d' END,
  COUNT(*)
FROM (
  SELECT GREATEST(TIMESTAMP_DIFF(s.started_at, r.answered_at, MINUTE), TIMESTAMP_DIFF(r.answered_at, s.finished_at, MINUTE)) AS m
  FROM r JOIN s ON r.session_id = s.session_id
  WHERE r.answered_at < s.started_at OR r.answered_at > s.finished_at
) GROUP BY 2

UNION ALL
SELECT 'C responses vs total_questions',
  CASE WHEN rp.n < s.total_questions THEN 'fewer responses' WHEN rp.n > s.total_questions THEN 'more responses' ELSE 'equal' END,
  COUNT(*)
FROM s JOIN (SELECT session_id, COUNT(*) AS n FROM r GROUP BY 1) rp ON s.session_id = rp.session_id
GROUP BY 2

UNION ALL
SELECT 'D subject by session_type / style', CONCAT(h.subject_name, ' | ', s.session_type, ' | ', s.style), COUNT(*)
FROM r JOIN s ON r.session_id = s.session_id JOIN h ON r.question_id = h.question_id
GROUP BY 2

UNION ALL
SELECT 'E incomplete vs null finished_at', CONCAT('complete=', CAST(is_complete AS STRING), ' finished_null=', CAST(finished_at IS NULL AS STRING)), COUNT(*)
FROM s GROUP BY 2

UNION ALL
SELECT 'F year group (Maths/English)', CONCAT(h.subject_name, ' | Y', CAST(s.year_group_at_sitting AS STRING)), COUNT(*)
FROM r JOIN s ON r.session_id = s.session_id JOIN h ON r.question_id = h.question_id
WHERE h.subject_name IN ('Maths', 'English') GROUP BY 2

ORDER BY check_name, n DESC;
