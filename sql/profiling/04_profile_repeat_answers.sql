-- Why do 747 sittings have more responses than total_questions? Here I Check for repeated answers to the same question.
WITH r AS (SELECT * FROM `atom-analytics-candidates.de_raw.responses`),
per_q AS (
  SELECT session_id, question_id, COUNT(*) AS n_answers,
         COUNT(DISTINCT question_number) AS n_question_numbers,
         COUNTIF(is_correct) AS n_correct
  FROM r GROUP BY 1, 2
)
SELECT 'G1 answers per (session, question)' AS check_name, CAST(n_answers AS STRING) AS detail, COUNT(*) AS n
FROM per_q GROUP BY 2
UNION ALL
SELECT 'G2 repeats where correctness differs', CAST(n_correct > 0 AND n_correct < n_answers AS STRING), COUNT(*)
FROM per_q WHERE n_answers > 1 GROUP BY 2
UNION ALL
SELECT 'G3 same question across different sittings (per pupil)', CAST(n AS STRING), COUNT(*)
FROM (SELECT pupil_id, question_id, COUNT(DISTINCT session_id) AS n FROM r GROUP BY 1, 2) GROUP BY 2
ORDER BY check_name, detail;
