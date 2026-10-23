-- Distribution of categorical fields used for filtering and subject mapping.
SELECT 'hierarchy.subject_name' AS field, subject_name AS val, COUNT(*) AS n
FROM `atom-analytics-candidates.de_raw.course_hierarchy` GROUP BY 1, 2
UNION ALL
SELECT 'sittings.session_type', session_type, COUNT(*)
FROM `atom-analytics-candidates.de_raw.assessment_sittings` GROUP BY 1, 2
UNION ALL
SELECT 'sittings.style', style, COUNT(*)
FROM `atom-analytics-candidates.de_raw.assessment_sittings` GROUP BY 1, 2
UNION ALL
SELECT 'sittings.year_group_at_sitting', CAST(year_group_at_sitting AS STRING), COUNT(*)
FROM `atom-analytics-candidates.de_raw.assessment_sittings` GROUP BY 1, 2
UNION ALL
SELECT 'responses.session_type', session_type, COUNT(*)
FROM `atom-analytics-candidates.de_raw.responses` GROUP BY 1, 2
ORDER BY field, n DESC;
