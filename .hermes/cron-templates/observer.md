# Observer Cron Template

Purpose: observe project state and write local artifacts only.

Rules:
- Use an absolute workdir.
- Deliver local output only until explicitly promoted.
- Do not create new cron jobs.
- Do not modify product code.
- If no new evidence exists, emit `[SILENT] no safe action`.
