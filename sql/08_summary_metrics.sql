-- 08_summary_metrics.sql
-- Headline figures quoted in the README. Run after 00-07.
SELECT 'staged responses' AS metric, CAST(COUNT(*) AS STRING) AS value FROM `atom-analytics-candidates.paul_martin.stg_responses`
UNION ALL SELECT 'scorable responses', CAST(COUNT(*) AS STRING) FROM `atom-analytics-candidates.paul_martin.int_scorable_responses`
UNION ALL SELECT CONCAT('excluded: ', exclusion_reason), CAST(COUNT(*) AS STRING) FROM `atom-analytics-candidates.paul_martin.dq_excluded_responses` GROUP BY exclusion_reason
UNION ALL SELECT 'score history rows', CAST(COUNT(*) AS STRING) FROM `atom-analytics-candidates.paul_martin.fct_pupil_sats_score_history`
UNION ALL SELECT 'current output rows', CAST(COUNT(*) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`
UNION ALL SELECT CONCAT('pupils with score: ', subject_name), CAST(COUNTIF(has_score) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current` GROUP BY subject_name
UNION ALL SELECT CONCAT('avg score: ', subject_name), CAST(ROUND(AVG(sats_scaled_score), 1) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current` GROUP BY subject_name
UNION ALL SELECT CONCAT('% meeting expected (100+): ', subject_name), CAST(ROUND(100 * SAFE_DIVIDE(COUNTIF(meets_expected_standard), COUNTIF(has_score)), 1) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current` GROUP BY subject_name
UNION ALL SELECT 'low-evidence current scores', CAST(COUNTIF(is_low_evidence) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`
UNION ALL SELECT 'scores floored at 80 (below official minimum)', CAST(COUNTIF(is_below_official_minimum) AS STRING) FROM `atom-analytics-candidates.paul_martin.pupil_sats_scores_current`
ORDER BY metric;
