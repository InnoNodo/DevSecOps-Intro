# Lab 2 Submission: Threat Modeling with Threagile

## Task 1: Threagile Baseline Model

### Generated Artifacts

Baseline threat model generated from `labs/lab2/threagile-model.yaml`:
- ✅ `labs/lab2/baseline/report.pdf` — Threat report with embedded diagrams
- ✅ `data-flow-diagram.png`, `data-asset-diagram.png`
- ✅ `risks.json`, `stats.json`, `technical-assets.json`

### Risk Ranking Methodology

Composite scores calculated using:
- **Severity**: critical (5) > elevated (4) > high (3) > medium (2) > low (1)
- **Likelihood**: very-likely (4) > likely (3) > possible (2) > unlikely (1)
- **Impact**: high (3) > medium (2) > low (1)
- **Composite Score**: `Severity × 100 + Likelihood × 10 + Impact`

### Top 5 Risks

| Rank | Category | Asset | Severity | Likelihood | Impact | Score |
|---:|---|---|---|---|---|---:|
| 1 | Unencrypted Communication | User Browser → Juice Shop | elevated | likely | high | **433** |
| 2 | Unencrypted Communication | Reverse Proxy → Juice Shop | elevated | likely | medium | **432** |
| 3 | Missing Authentication | Reverse Proxy → Juice Shop | elevated | likely | medium | **432** |
| 4 | Cross-Site Scripting (XSS) | Juice Shop Application | elevated | likely | medium | **432** |
| 5 | Cross-Site Request Forgery (CSRF) | Juice Shop Application | medium | very-likely | low | **241** |

### Critical Security Findings

**Elevated Severity Issues:**
- **Unencrypted Communication (Direct to App)**: HTTP on port 3000 transmits credentials/tokens in cleartext → MITM risk
- **Unencrypted Communication (Proxy to App)**: Internal communication uses unencrypted HTTP → lateral movement risk
- **Missing Authentication (Proxy to App)**: No auth between reverse proxy and app → spoofing risk
- **Cross-Site Scripting (XSS)**: Inadequate input validation → session hijacking risk

**Risk Distribution**: 23 total risks (13% elevated, 61% medium, 26% low)


## Task 2: HTTPS Variant & Risk Comparison

### Secure Model Changes

File: `labs/lab2/threagile-model.secure.yaml`

Changes made:
1. User Browser → Direct to App: `http` → `https`
2. Reverse Proxy → To App: `http` → `https`
3. Persistent Storage: encryption `none` → `transparent`

### Generated Artifacts

- ✅ `labs/lab2/secure/report.pdf` — Updated threat report
- ✅ `data-flow-diagram.png`, `data-asset-diagram.png`
- ✅ `risks.json`, `stats.json`, `technical-assets.json`

### Risk Category Delta Comparison

| Category | Baseline | Secure | Delta |
|---|---:|---:|---:|
| container-baseimage-backdooring | 1 | 1 | +0 |
| cross-site-request-forgery | 2 | 2 | +0 |
| cross-site-scripting | 1 | 1 | +0 |
| missing-authentication | 1 | 1 | +0 |
| missing-authentication-second-factor | 2 | 2 | +0 |
| missing-build-infrastructure | 1 | 1 | +0 |
| missing-hardening | 2 | 2 | +0 |
| missing-identity-store | 1 | 1 | +0 |
| missing-vault | 1 | 1 | +0 |
| missing-waf | 1 | 1 | +0 |
| server-side-request-forgery | 2 | 2 | +0 |
| unencrypted-asset | 2 | 1 | **-1** |
| unencrypted-communication | 2 | 0 | **-2** |
| unnecessary-data-transfer | 2 | 2 | +0 |
| unnecessary-technical-asset | 2 | 2 | +0 |

**Summary**: Baseline 23 risks → Secure 20 risks (**-3 risks / -13% reduction**)

### Delta Run Explanation

**Eliminated Risks: Unencrypted Communication (-2)**
- Changed HTTP → HTTPS on user-browser→app and proxy→app connections
- Eliminates cleartext credential transmission (eliminates MITM attack vectors)
- These were the #1 and #2 highest-scoring risks (433 and 432 composite scores)

**Reduced Risks: Unencrypted Asset (-1)**
- Changed Persistent Storage encryption from `none` → `transparent`
- Protects data at rest (database, uploads, logs)
- Reduces offline filesystem attack risk

**Unchanged Risks (14 categories)**
- Application-level vulnerabilities (XSS, CSRF, SSRF) remain unchanged because they require code fixes, not deployment changes
- Missing architectural controls (WAF, vault, identity store) unchanged
- Encryption alone does not address logic-level flaws in the application

**Key Finding**: 13% risk reduction demonstrates encryption in transit is critical for eliminating high-impact threats, but application hardening and security architecture improvements remain necessary for comprehensive protection.

### Diagram Comparison

**Baseline Diagrams** (`labs/lab2/baseline/`):
- **Data Flow Diagram**: Shows HTTP flows with unencrypted communication links
- **Data Asset Diagram**: Sensitive data flowing through unencrypted channels

**Secure Variant Diagrams** (`labs/lab2/secure/`):
- **Data Flow Diagram**: Updated with HTTPS on user-browser→app and proxy→app connections
- **Data Asset Diagram**: Same assets with encrypted channel indicators and transparent storage encryption

**Observation**: Encryption controls are visually reflected in diagrams, confirming the security improvements quantified in the risk analysis.
