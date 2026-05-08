# Lab 5 Submission - SAST and Multi-Tool DAST Analysis

## Task 1 - SAST with Semgrep

### Scope and Evidence

Target source: OWASP Juice Shop `v19.0.0` cloned under `labs/lab5/semgrep/juice-shop`.

Evidence files:

- `labs/lab5/semgrep/semgrep-results.json`
- `labs/lab5/analysis/sast-analysis.txt`

Semgrep reported **8 code-level findings**. The custom/security rules detected high-signal issues in server-side TypeScript routes, especially unsafe dynamic evaluation, raw SQL string construction, weak hashing, and user-controlled redirects.

### SAST Tool Effectiveness

Semgrep was effective for vulnerabilities that can be recognized directly in source code before deployment. In this run it found:

- SQL injection pattern in `routes/search.ts`
- unsafe `eval()` usage in `routes/captcha.ts` and `routes/userProfile.ts`
- insecure MD5 hashing in `lib/insecurity.ts`
- multiple open redirect paths in route handlers

The result set is smaller than a full dependency scanner because this SAST run focused on code patterns, not package CVEs. Its main value is early developer feedback: it identifies dangerous implementation constructs before the application is running.

### Five Most Critical Semgrep Findings

| # | Vulnerability type | File and line | Severity | Evidence |
|---:|---|---|---|---|
| 1 | SQL injection via raw SQL string interpolation | `/src/routes/search.ts:23` | ERROR | `output.juice-shop-sql-string-interpolation` |
| 2 | Dynamic code execution with `eval()` | `/src/routes/captcha.ts:23` | ERROR | `output.juice-shop-eval` |
| 3 | Dynamic code execution with `eval()` | `/src/routes/userProfile.ts:62` | ERROR | `output.juice-shop-eval` |
| 4 | Weak cryptographic hash | `/src/lib/insecurity.ts:43` | WARNING | `output.juice-shop-md5-hash` |
| 5 | User-controlled redirect | `/src/routes/redirect.ts:19` | WARNING | `output.juice-shop-open-redirect` |

## Task 2 - DAST with ZAP, Nuclei, Nikto, and SQLmap

### Scope and Evidence

Target runtime: `bkimminich/juice-shop:v19.0.0` on `http://localhost:3000`.

Evidence files:

- `labs/lab5/zap/zap-report-noauth.json`
- `labs/lab5/zap/report-noauth.html`
- `labs/lab5/zap/zap-report-auth.json`
- `labs/lab5/zap/report-auth.html`
- `labs/lab5/zap/auth-check.txt`
- `labs/lab5/zap/admin-application-configuration.json`
- `labs/lab5/nuclei/nuclei-results.json`
- `labs/lab5/nikto/nikto-results.txt`
- `labs/lab5/sqlmap/search-scan.log`
- `labs/lab5/sqlmap/login-scan.log`
- `labs/lab5/sqlmap/results-05082026_1141am.csv`

### Authenticated vs Unauthenticated ZAP Scanning

| Scan | URLs reported by ZAP | Alert rules | Alert instances | Severity breakdown |
|---|---:|---:|---:|---|
| Unauthenticated baseline | 95 | 13 | 133 | 2 Medium, 6 Low, 5 Informational |
| Authenticated baseline with JWT header | 95 | 11 | 94 | 2 Medium, 5 Low, 4 Informational |

The authenticated scan used a Juice Shop admin JWT as an `Authorization: Bearer ...` header. Authentication was verified separately by successfully requesting `/rest/admin/application-configuration`, saved in `labs/lab5/zap/admin-application-configuration.json`.

In this run the ZAP baseline spider still discovered the same top-level URL count because it did not execute a full logged-in browser workflow. Even so, the authenticated setup matters: APIs that require a session token, such as `/rest/admin/application-configuration`, cannot be assessed correctly with a purely anonymous scanner. For production-grade testing, the stronger approach would be ZAP Automation Framework with browser-based login, AJAX spider, and authenticated active scan.

### Tool Comparison Matrix

| Tool | Findings | Severity breakdown | Best use case |
|---|---:|---|---|
| ZAP unauthenticated | 13 alert rules / 133 instances | 2 Medium, 6 Low, 5 Informational | Broad web app baseline, passive checks, headers, content issues |
| ZAP authenticated | 11 alert rules / 94 instances | 2 Medium, 5 Low, 4 Informational | Testing authenticated/API surfaces when a valid session is available |
| Nuclei | 1 template match | 1 Info | Fast known-template discovery and exposed endpoint detection |
| Nikto | 84 reported items | Nikto text findings, mostly headers/exposed files | Web server misconfiguration and interesting file/path checks |
| SQLmap | 2 injectable endpoints | Search and login confirmed SQL injection against SQLite | Deep SQL injection confirmation and exploitation evidence |

### Tool-Specific Strengths and Example Findings

**ZAP** is best for broad web application coverage and HTTP response analysis. It found missing Content Security Policy, cross-domain misconfiguration, dangerous JavaScript functions, suspicious comments, and timestamp disclosure.

**Nuclei** is fast and template-driven. It detected a public Swagger/OpenAPI surface at `/api-docs/swagger.yaml`, which is useful for API discovery and attack surface mapping.

**Nikto** is useful for web server and path-oriented checks. It reported missing `strict-transport-security`, `referrer-policy`, `permissions-policy`, and `content-security-policy` headers. It also flagged interesting paths such as `/ftp/`, `/public/`, and `/.htpasswd`.

**SQLmap** is the strongest tool here for SQL injection confirmation. It confirmed:

- `GET /rest/products/search?q=*` as boolean-based blind SQL injection against SQLite
- `POST /rest/user/login` JSON `email` parameter as boolean-based blind SQL injection against SQLite

The login scan also started dumping database content. I stopped it after evidence was collected because the full dump exceeded the practical runtime for this lab execution.

## Task 3 - SAST/DAST Correlation and Security Assessment

### Findings Summary

| Category | Result count |
|---|---:|
| SAST: Semgrep code findings | 8 |
| DAST: ZAP unauthenticated alert rules | 13 |
| DAST: ZAP authenticated alert rules | 11 |
| DAST: Nuclei matches | 1 |
| DAST: Nikto items | 84 |
| DAST: SQLmap confirmed injection points | 2 |

### Correlation

The clearest correlation is SQL injection. Semgrep found the unsafe SQL construction in `routes/search.ts`, and SQLmap confirmed that the running application is exploitable through `/rest/products/search?q=*`. This is a strong example of SAST and DAST reinforcing the same risk from different angles: source-level root cause plus runtime exploitability.

SAST-only findings in this run:

- unsafe `eval()` in source code
- weak MD5 hashing implementation
- open redirect code paths in route handlers

DAST-only findings in this run:

- missing or weak HTTP security headers
- public Swagger/OpenAPI exposure
- interesting runtime paths and files such as `/ftp/`, `/public/`, and `/.htpasswd`

### Recommendations

1. Use Semgrep in pull requests to catch dangerous code constructs early, especially raw SQL, dynamic evaluation, weak crypto, and redirect logic.
2. Use ZAP against deployed environments to catch HTTP headers, browser-visible issues, and authenticated attack surface.
3. Use Nuclei as a quick template-based exposure check in CI or scheduled scans.
4. Use Nikto for server/path misconfiguration checks during deployment validation.
5. Use SQLmap only in controlled environments for targeted confirmation when SAST or DAST suggests SQL injection risk.
6. Fix the confirmed SQL injection by replacing string-built SQL with parameterized queries.
7. Add strict HTTP security headers, especially CSP, HSTS, Referrer-Policy, and Permissions-Policy.
