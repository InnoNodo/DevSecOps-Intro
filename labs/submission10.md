# Lab 10 Submission - Vulnerability Management and Response with DefectDojo

## Scope and Setup
- Date completed: 2026-04-13
- DefectDojo was cloned into `labs/lab10/setup/django-DefectDojo` and started locally with Docker Compose.
- Product hierarchy created through the import workflow:
  - Product Type: `Engineering`
  - Product: `Juice Shop`
  - Engagement: `Labs Security Testing`
- Setup evidence is recorded in `labs/lab10/setup/setup-evidence.md`.

## Task 1 - DefectDojo Local Setup
- DefectDojo services were started successfully and the nginx, uwsgi, postgres, valkey, celery beat, and celery worker containers were all confirmed running.
- An admin API token was generated inside the Dojo application container so imports and reporting could be automated without manual UI steps.
- The working evidence and cloned upstream setup are stored under `labs/lab10/setup/`.

## Task 2 - Import Prior Findings
- Imported scan data from five tools into the `Labs Security Testing` engagement:
  - ZAP Scan: 13 findings
  - Semgrep JSON Report: 8 findings
  - Trivy Scan: 147 findings
  - Nuclei Scan: 1 finding
  - Anchore Grype: 122 findings
- Total findings imported into DefectDojo: **291**
- Import metadata is stored in `labs/lab10/imports/import-summary.json`.
- Note: the ZAP baseline output available in the repo was JSON, but DefectDojo’s `ZAP Scan` parser expects XML. I converted the JSON report into a compatible XML artifact and imported that XML file successfully.

## Task 3 - Report and Metrics Package
- Baseline dashboard snapshot on 2026-04-13:
  - Active findings: **291**
  - Verified findings: **143**
  - Mitigated findings: **0**
- Open vs. closed by severity:
  - Critical: 21 open, 0 closed
  - High: 150 open, 0 closed
  - Medium: 75 open, 0 closed
  - Low: 27 open, 0 closed
  - Informational: 18 open, 0 closed
- Stakeholder summary highlights:
  - The current backlog is dominated by supply-chain findings from Trivy and Grype, which together account for 269 of 291 findings, while DAST results from ZAP and Nuclei added 14 web-facing issues and Semgrep added 8 code findings.
  - Severity concentration is weighted heavily toward high and medium risk items, with 150 high, 75 medium, and 21 critical findings active in the initial snapshot.
  - No findings are mitigated yet, which is expected for a first import baseline, but 143 Trivy findings are already marked verified by the parser and should be prioritized for triage first.
  - SLA pressure is emerging rather than overdue: 0 active findings are already past SLA, while 21 active findings are due within the next 14 days.
  - The most frequent recurring CWE identifiers in the imported dataset are CWE-1333 (29 findings), CWE-407 (13), and CWE-22 (11), followed by CWE-20, CWE-674, and CWE-1321 with 6 findings each.

## Delivered Artifacts
- `labs/lab10/setup/setup-evidence.md`
- `labs/lab10/imports/import-summary.json`
- `labs/lab10/report/metrics-snapshot.md`
- `labs/lab10/report/metrics-summary.json`
- `labs/lab10/report/dojo-report.html`
- `labs/lab10/report/findings.csv`
