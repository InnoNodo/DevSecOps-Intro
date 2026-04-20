# Lab 11 Submission - Reverse Proxy Hardening with Nginx

## Scope and Setup
- Date completed: 2026-04-20
- Stack directory: `labs/lab11`
- Target application: `bkimminich/juice-shop:v19.0.0`
- Reverse proxy: `nginx:stable-alpine`
- Evidence artifacts are stored under `labs/lab11/analysis/`

## Task 1 - Reverse Proxy Compose Setup
- A local self-signed certificate for `localhost` was generated and mounted into the Nginx container.
- The stack was started with Docker Compose and only the Nginx service published host ports:
  - `8080/tcp` for HTTP redirect handling
  - `8443/tcp` for HTTPS
- Juice Shop was not published directly to the host; it is only reachable on the internal Docker network as `juice:3000`.
- Reverse proxies improve security because they centralize TLS termination, enforce security headers without touching app code, add request filtering and rate limiting, and provide a single controlled ingress point in front of the application.
- Hiding direct app ports reduces attack surface by removing a bypass path around proxy controls. Clients cannot skip the hardened proxy and talk to the application process directly.

### Command Evidence
`docker compose ps` from `labs/lab11/analysis/docker-compose-ps.txt`:

```text
NAME            IMAGE                           COMMAND                  SERVICE   CREATED              STATUS              PORTS
lab11-juice-1   bkimminich/juice-shop:v19.0.0   "/nodejs/bin/node /j…"   juice     About a minute ago   Up About a minute   3000/tcp
lab11-nginx-1   nginx:stable-alpine             "/docker-entrypoint.…"   nginx     About a minute ago   Up About a minute   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 80/tcp, 0.0.0.0:8443->8443/tcp, [::]:8443->8443/tcp
```

HTTP redirect result from `labs/lab11/analysis/http-redirect.txt`:

```text
HTTP 308
```

## Task 2 - Security Headers
- HTTP and HTTPS responses were checked with `curl -I`.
- The configured hardening headers were present, and HSTS appeared only on HTTPS as intended.
- CSP is in `Report-Only` mode so the proxy can surface policy violations without breaking Juice Shop’s frontend behavior.

### Relevant HTTPS Headers
From `labs/lab11/analysis/headers-https.txt`:

```text
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-frame-options: DENY
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
permissions-policy: camera=(), geolocation=(), microphone=()
cross-origin-opener-policy: same-origin
cross-origin-resource-policy: same-origin
content-security-policy-report-only: default-src 'self'; img-src 'self' data:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'
```

### Header Purpose
- **X-Frame-Options**: prevents clickjacking by blocking framing of the site.
- **X-Content-Type-Options**: prevents MIME sniffing so browsers do not reinterpret content as a more dangerous type.
- **Strict-Transport-Security (HSTS)**: tells browsers to use HTTPS for future requests and reduces SSL stripping risk.
- **Referrer-Policy**: limits how much URL/referrer data is leaked to other origins.
- **Permissions-Policy**: disables unnecessary browser capabilities such as camera, geolocation, and microphone.
- **COOP/CORP**: isolates the browsing context and resource loading to reduce cross-origin data leaks and some XS-Leaks style issues.
- **CSP-Report-Only**: tests a CSP without enforcing it yet, which is safer for a complex app that may otherwise break under a strict policy.

## Task 3 - TLS, HSTS, Rate Limiting, and Timeouts

### TLS and HSTS Summary
- HTTPS on `8443` successfully negotiated both `TLSv1.2` and `TLSv1.3`.
- The TLS evidence file `labs/lab11/analysis/testssl.txt` contains raw `openssl` probe output from the same endpoint.
- Negotiated ciphers observed:
  - `TLSv1.3`: `TLS_AES_256_GCM_SHA384`
  - `TLSv1.2`: `ECDHE-RSA-AES256-GCM-SHA384`
- The configured cipher list also allows modern AEAD suites including:
  - `TLS_CHACHA20_POLY1305_SHA256`
  - `TLS_AES_128_GCM_SHA256`
  - `ECDHE-RSA-AES128-GCM-SHA256`
  - `DHE-RSA-AES256-GCM-SHA384`
- TLSv1.1 was rejected, which is consistent with `ssl_protocols TLSv1.2 TLSv1.3;` in `labs/lab11/reverse-proxy/nginx.conf`.
- TLSv1.2+ is required because older versions are deprecated and vulnerable to outdated cryptographic behavior; TLSv1.3 is preferred because it simplifies negotiation and removes legacy constructs.
- Warning observed: the certificate is self-signed, so trust validation fails in development. This is expected for localhost.
- Additional development caveats remain by design:
  - OCSP stapling is disabled in `nginx.conf`
  - There is no public CA trust chain for the local certificate
- HSTS was confirmed only on HTTPS:
  - Present in `labs/lab11/analysis/headers-https.txt`
  - Absent in `labs/lab11/analysis/headers-http.txt`

### Rate Limiting Results
- The login endpoint `/rest/user/login` was protected with `limit_req zone=login burst=5 nodelay`.
- Observed results from `labs/lab11/analysis/rate-limit-test.txt`:
  - `401`: 6 responses
  - `429`: 6 responses
- This shows normal authentication failures were allowed initially, then excessive bursts were blocked by Nginx.
- `rate=10r/m` means each client IP gets about 10 login requests per minute in steady state.
- `burst=5` allows a small short-term spike before blocking, which is a practical balance between bot resistance and normal user behavior like retries or page reloads.

### Timeout Discussion
- `client_body_timeout 10s` limits how long Nginx waits for the request body, which helps against slow upload abuse.
- `client_header_timeout 10s` limits slow header delivery, which helps against slowloris-style attacks.
- `proxy_read_timeout 30s` limits how long Nginx waits for the upstream response, reducing worker exhaustion from stalled backends.
- `proxy_send_timeout 30s` limits how long Nginx waits while sending data upstream.
- Trade-off: tighter timeouts reduce DoS exposure, but if they are too aggressive they can terminate slow legitimate clients or long backend operations.

### Log Evidence
Relevant `429` access-log lines from `labs/lab11/analysis/access-log-429.txt`:

```text
192.168.64.1 - - [20/Apr/2026:12:50:13 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.5.0" rt=0.000 uct=- urt=-
192.168.64.1 - - [20/Apr/2026:12:50:13 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.5.0" rt=0.000 uct=- urt=-
192.168.64.1 - - [20/Apr/2026:12:50:13 +0000] "POST /rest/user/login HTTP/2.0" 429 162 "-" "curl/8.5.0" rt=0.000 uct=- urt=-
```

Matching rate-limit warnings from `labs/lab11/analysis/error-log-rate-limit.txt`:

```text
2026/04/20 12:50:13 [warn] 37#37: *18 limiting requests, excess: 5.970 by zone "login", client: 192.168.64.1, server: _, request: "POST /rest/user/login HTTP/2.0", host: "localhost:8443"
2026/04/20 12:50:13 [warn] 38#38: *19 limiting requests, excess: 5.959 by zone "login", client: 192.168.64.1, server: _, request: "POST /rest/user/login HTTP/2.0", host: "localhost:8443"
2026/04/20 12:50:13 [warn] 39#39: *20 limiting requests, excess: 5.956 by zone "login", client: 192.168.64.1, server: _, request: "POST /rest/user/login HTTP/2.0", host: "localhost:8443"
```

## Delivered Artifacts
- `labs/lab11/analysis/docker-compose-ps.txt`
- `labs/lab11/analysis/http-redirect.txt`
- `labs/lab11/analysis/headers-http.txt`
- `labs/lab11/analysis/headers-https.txt`
- `labs/lab11/analysis/testssl.txt`
- `labs/lab11/analysis/rate-limit-test.txt`
- `labs/lab11/analysis/access-log-429.txt`
- `labs/lab11/analysis/error-log-rate-limit.txt`
- `labs/submission11.md`
