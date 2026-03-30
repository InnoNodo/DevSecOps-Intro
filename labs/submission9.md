# Lab 9 Submission

## Task 1 - Runtime Security Detection with Falco

### Setup
- Helper container: `alpine:3.19`, started as `lab9-helper`
- Falco image: `falcosecurity/falco:latest`
- Runtime engine: modern eBPF
- Custom rules path: `labs/lab9/falco/rules/custom-rules.yaml`

### Custom Falco Rule
File: `labs/lab9/falco/rules/custom-rules.yaml`

Purpose:
- Detect direct writes to `/usr/local/bin/` from inside any container.
- This is a simple drift/compliance control because binaries or executable drop locations inside a container should not be modified during normal runtime.

When it should fire:
- A container writes or creates a file under `/usr/local/bin/`
- The open operation is a write (`evt.is_open_write=true`)

When it should not fire:
- Host-side writes
- Container reads without write flags
- Writes outside `/usr/local/bin/`

### Alerts Observed

Baseline helper-container alert:
- `Terminal shell in container`
- Evidence from `labs/lab9/falco/logs/falco.log`:

```json
{"rule":"Terminal shell in container","time":"2026-03-30T18:56:02.965015653Z","output":"Notice A shell was spawned in a container with an attached terminal | command=sh -lc echo tty-shell-trigger; sleep 1 container_name=lab9-helper"}
```

Custom-rule alert:
- `Write Binary Under UsrLocalBin`
- Triggered by:
  - `echo boom > /usr/local/bin/drift.txt`
  - `echo custom-test > /usr/local/bin/custom-rule.txt`

```json
{"rule":"Write Binary Under UsrLocalBin","time":"2026-03-30T18:55:15.156585848Z","output":"Warning Falco Custom: File write in /usr/local/bin (container=lab9-helper user=root file=/usr/local/bin/drift.txt ...)"}
{"rule":"Write Binary Under UsrLocalBin","time":"2026-03-30T18:55:15.156527201Z","output":"Warning Falco Custom: File write in /usr/local/bin (container=lab9-helper user=root file=/usr/local/bin/custom-rule.txt ...)"}
```

Additional Falco verification from the event generator:
- `Drop and execute new binary in container`
- `Fileless execution via memfd_create`

These showed that Falco was detecting more than just the custom helper-container activity.

### Tuning / Noise Notes
- On this WSL2 host, Falco started successfully with modern eBPF but logged TOCTOU mitigation attachment warnings for some tracepoints (`open`, `openat`, `openat2`, `creat`).
- Detection still worked, but the built-in drift rule did not clearly appear in the captured output. The custom rule provided deterministic evidence for the `/usr/local/bin` write behavior required by the lab.
- The custom rule is intentionally narrow to keep noise low. It only watches one high-signal path and excludes host events with `container.id != host`.

## Task 2 - Policy-as-Code with Conftest

### Kubernetes Manifest Comparison
`juice-unhardened.yaml` is intentionally minimal and violates multiple security requirements:
- Uses `bkimminich/juice-shop:latest`
- No `securityContext`
- No resource requests/limits
- No probes

`juice-hardened.yaml` fixes those gaps:
- Pins the image to `bkimminich/juice-shop:v19.0.0`
- Adds `runAsNonRoot: true`
- Adds `allowPrivilegeEscalation: false`
- Adds `readOnlyRootFilesystem: true`
- Drops all Linux capabilities
- Adds CPU and memory requests/limits
- Adds readiness and liveness probes

### Conftest Results

Unhardened Kubernetes manifest:
- Result: `30 tests, 20 passed, 2 warnings, 8 failures, 0 exceptions`
- Evidence: `labs/lab9/analysis/conftest-unhardened.txt`

Why each failure matters:
- `:latest` tag: non-deterministic deployments and harder rollback/audit
- Missing `runAsNonRoot`: increases impact if the process is compromised
- Missing `allowPrivilegeEscalation: false`: allows gaining extra privileges through setuid/setgid or similar paths
- Missing `readOnlyRootFilesystem`: makes runtime tampering and persistence easier
- Missing resource requests/limits: weakens scheduling guarantees and enables noisy-neighbor or resource exhaustion issues

Warnings on the unhardened manifest:
- Missing `readinessProbe`
- Missing `livenessProbe`

These are warnings rather than denials because they affect resilience and safe rollout behavior more than direct privilege boundaries.

Hardened Kubernetes manifest:
- Result: `30 tests, 30 passed, 0 warnings, 0 failures, 0 exceptions`
- Evidence: `labs/lab9/analysis/conftest-hardened.txt`

Docker Compose manifest:
- Result: `15 tests, 15 passed, 0 warnings, 0 failures, 0 exceptions`
- Evidence: `labs/lab9/analysis/conftest-compose.txt`

Why the Compose file passes:
- Explicit non-root user: `10001:10001`
- `read_only: true`
- `cap_drop: ["ALL"]`
- `security_opt: ["no-new-privileges:true"]`
- `tmpfs: ["/tmp"]` provides a writable temp location without making the whole filesystem writable

## Files Produced
- `labs/lab9/falco/rules/custom-rules.yaml`
- `labs/lab9/falco/logs/falco.log`
- `labs/lab9/analysis/conftest-unhardened.txt`
- `labs/lab9/analysis/conftest-hardened.txt`
- `labs/lab9/analysis/conftest-compose.txt`
