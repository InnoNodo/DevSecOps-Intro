# Lab 4 Submission - SBOM Generation and SCA Comparison

## Scope and Environment
- Target image: `bkimminich/juice-shop:v19.0.0`
- Tools used:
  - `anchore/syft:latest` for SBOM generation
  - `anchore/grype:latest` for SCA over Syft SBOM
  - `aquasec/trivy:latest` for SBOM/vulnerability/secrets/license scanning
- All raw outputs are saved under `labs/lab4/`.

## Task 1 - SBOM Generation with Syft and Trivy

### Commands Executed
- Generated Syft SBOM in native JSON and table format.
- Generated Trivy package inventory in JSON and table format.
- Extracted component and license summaries into `labs/lab4/analysis/sbom-analysis.txt`.

### Package Type Distribution
- Syft total packages: **1139**
  - `npm`: 1128
  - `deb`: 10
  - `binary`: 1
- Trivy total packages: **1135**
  - Node.js (`lang-pkgs`): 1125
  - Debian OS packages (`os-pkgs`): 10

### Dependency Discovery Analysis
- Syft produced explicit relationship metadata: **3551 artifact relationships**.
- Trivy output provides strong package inventory by target/class but less explicit dependency graph detail in this run.
- Practical result: for dependency graphing and transitive relationship analysis, Syft output was richer.

### License Discovery Analysis
- Syft unique license expressions: **32**
- Trivy unique license expressions: **28**
- Syft found a broader expression set (including mixed expressions like `(MIT OR Apache-2.0)` and hash-like/ad-hoc values), while Trivy normalized many licenses more consistently (for example `-only`/`-or-later` style SPDX forms in OS packages).

## Task 2 - Software Composition Analysis with Grype and Trivy

### SCA Tool Comparison (Detection Volume)
- Grype severities:
  - Critical: 11
  - High: 88
  - Medium: 32
  - Low: 3
  - Negligible: 12
- Trivy severities:
  - Critical: 10
  - High: 81
  - Medium: 34
  - Low: 18

Observation: Grype reported slightly more total high/critical findings in this dataset, while Trivy returned broader low/medium volume.

### Critical Vulnerabilities Analysis (Top 5 with Remediation)
1. `CVE-2023-32314` (`vm2` 3.9.17, CVSS 10.0)
- Fix: upgrade to `vm2` >= `3.9.18`.

2. `CVE-2023-37466` (`vm2` 3.9.17, CVSS 10.0)
- Fix: upgrade to `vm2` >= `3.10.0`.

3. `CVE-2026-22709` (`vm2` 3.9.17, CVSS 10.0)
- Fix: upgrade to `vm2` >= `3.10.2`.

4. `CVE-2025-15467` (`libssl3` 3.0.17-1~deb12u2, CVSS 9.8)
- Fix: update OS package to `3.0.18-1~deb12u2` or newer.

5. `CVE-2015-9235` (`jsonwebtoken` 0.1.0 / 0.4.0, CVSS 9.8)
- Fix: upgrade `jsonwebtoken` to >= `4.2.2` (prefer latest stable major in practice).

### License Compliance Assessment
- Potentially restrictive/copyleft licenses detected (GPL/LGPL patterns):
  - Syft: 28 packages
  - Trivy: 25 packages
- Compliance recommendation:
  - Maintain an allow/deny license policy in CI.
  - Flag GPL/LGPL components for legal review before production redistribution.
  - Prefer SPDX-normalized license fields in internal reporting for policy automation.

### Additional Security Features (Secrets)
- Trivy secret scan found **no secrets** in the scanned image/package targets (`Secrets: -` across reported targets).

## Task 3 - Toolchain Comparison (Syft+Grype vs Trivy)

### Accuracy Analysis
From `labs/lab4/comparison/accuracy-analysis.txt`:
- Packages detected by both tools: **1126**
- Packages only by Syft: **13**
- Packages only by Trivy: **9**
- CVEs found by Grype: **95**
- CVEs found by Trivy: **91**
- Common CVEs: **26**

Interpretation: package inventory overlap is high, but vulnerability overlap is comparatively low, indicating database/advisory-source and matching-strategy differences.

### Tool Strengths and Weaknesses
- Syft + Grype strengths:
  - Rich SBOM metadata and dependency relationships.
  - Flexible decoupled pipeline (`SBOM -> scan`) suitable for artifact retention and re-scanning.
  - Slightly higher CVE count in this run.
- Syft + Grype weaknesses:
  - Two-tool workflow increases integration and maintenance overhead.
  - Requires explicit orchestration for licenses/secrets beyond core flow.
- Trivy strengths:
  - Single tool for vuln + secrets + license + package inventory.
  - Simple adoption path and faster onboarding for teams.
- Trivy weaknesses:
  - Relationship/dependency graph depth was less explicit than Syft native output.
  - CVE overlap differences may require cross-tool validation for high-stakes triage.

### Use Case Recommendations
- Choose **Syft + Grype** when:
  - You need durable SBOM artifacts, richer relationship data, or independent SBOM re-scans.
  - You want to separate SBOM generation from vulnerability scanning in CI/CD.
- Choose **Trivy all-in-one** when:
  - You need one command surface for vulnerability, secret, and license checks.
  - You prioritize operational simplicity and broad scanner coverage in a single stage.

### Integration Considerations (CI/CD and Operations)
- Cache vulnerability databases to avoid repeated large downloads per pipeline run.
- Store generated SBOMs as build artifacts and sign/attest where possible.
- Gate PRs on severity thresholds plus license policy checks.
- For critical findings, cross-check across both toolchains before patch prioritization to reduce blind spots.

## Issues Encountered
- `jq` was not installed locally, so JSON extraction was completed with a containerized `jq` image (`ghcr.io/jqlang/jq:latest`).
- Trivy DB downloads were slow during scans; persistent cache mounting is recommended for CI performance.
