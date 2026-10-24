# How I used AI on this task

I used Claude as a pair-programming assistant throughout, consistent with the brief's encouragement to use AI. `chat_log.md` is an edited reconstruction of the task-relevant collaboration, organised as a Paul/Claude question-and-answer log; it is paraphrased and consolidated rather than a verbatim transcript.

## What Claude helped with

- Reviewing the task requirements and proposing an initial layered model design.
- Looking up the official 2025 KS2 SATs conversion tables and drafting the conversion seed SQL.
- Drafting profiling queries, SQL model files, test assertions, the README and the decisions log.
- Reviewing the implications of the profiling results and helping document the architecture and GCSE prediction approach.
- Providing some repository and tooling guidance.

## What I did

- Inspected the available source schema and ran the profiling queries in BigQuery.
- Interpreted the query outputs and chose the data-handling rules for orphaned responses, incomplete and survey sittings, stale session-type values, timestamp discrepancies and repeated answers.
- Asked Carmen to resolve the English-to-SATs mapping ambiguity, then applied the team's confirmation to use the KS2 Reading conversion table.
- Ran the pipeline models, reviewed the materialised outputs, and reconciled the scorable and excluded counts to the complete staged response count.
- Ran the complete rebuild twice and confirmed both runs returned the same fingerprint (`-6722694541268686623`) and 1,719 history rows.
- Reviewed the SQL and documentation and organised the repository into logical commits.

## How I verified the AI-assisted output

- Assertions in `07_tests.sql` check uniqueness, score range, one current row per pupil/subject and accounting for every response.
- The summary metrics in `08_summary_metrics.sql` were checked against the materialised model outputs.
- The SATs conversion data was checked against the official GOV.UK source.
- The counts reconcile: 44,366 scorable responses + 19,341 excluded responses = 63,707 staged responses.
- The two full runs returned identical fingerprints and row counts, providing a reproducibility check for the available dataset.
