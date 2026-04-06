# Lab 9 Submission

## Task 1 - Runtime Security Detection with Falco

### Setup
- Verified on branch `feature/lab9`
- Helper container: `alpine:3.19`, started as `lab9-helper`
- Falco image: `falcosecurity/falco:latest`
- Runtime engine: modern eBPF
- Custom rules file: `labs/lab9/falco/rules/custom-rules.yaml`
- Log evidence: `labs/lab9/falco/logs/falco.log`

### Custom Falco Rule
Rule file: `labs/lab9/falco/rules/custom-rules.yaml`

Purpose:
- Detect write activity under `/usr/local/bin/` from inside a container.
- Treat runtime writes to a binary path as a high-signal drift/compliance event.

When it should fire:
- A container creates or overwrites a file below `/usr/local/bin/`
- The operation is a write-capable open event

When it should not fire:
- Host-side activity
- Read-only opens
- Writes outside `/usr/local/bin/`

### Alerts Observed

Baseline alert from the helper container:
- Rule: `Terminal shell in container`
- Trigger: `docker exec -it lab9-helper /bin/sh -lc 'echo hello-from-shell; sleep 1'`

```json
{"rule":"Terminal shell in container","time":"2026-04-06T16:02:57.648777170Z","output":"Notice A shell was spawned in a container with an attached terminal | command=sh -lc echo hello-from-shell; sleep 1 container_name=lab9-helper"}
```

Custom-rule alerts:
- Rule: `Write Binary Under UsrLocalBin`
- Triggers:
  - `echo boom > /usr/local/bin/drift.txt`
  - `echo custom-test > /usr/local/bin/custom-rule.txt`

```json
{"rule":"Write Binary Under UsrLocalBin","time":"2026-04-06T16:03:10.436779758Z","output":"Warning Falco Custom: File write in /usr/local/bin (container=lab9-helper user=root file=/usr/local/bin/custom-rule.txt flags=O_LARGEFILE|O_TRUNC|O_CREAT|O_WRONLY|O_F_CREATED|FD_UPPER_LAYER)"}
{"rule":"Write Binary Under UsrLocalBin","time":"2026-04-06T16:03:10.436850893Z","output":"Warning Falco Custom: File write in /usr/local/bin (container=lab9-helper user=root file=/usr/local/bin/drift.txt flags=O_LARGEFILE|O_TRUNC|O_CREAT|O_WRONLY|O_F_CREATED|FD_UPPER_LAYER)"}
```

Additional Falco verification from `falcosecurity/event-generator:latest`:
- `Drop and execute new binary in container`
- `Execution from /dev/shm`
- `Run shell untrusted`

This confirmed the Falco deployment was detecting both the targeted helper-container activity and broader suspicious runtime behavior.

### Tuning / Noise Notes
- Falco started successfully with modern eBPF on WSL2.
- Falco logged TOCTOU mitigation attachment warnings for `connect`, `creat`, `open`, `openat`, and `openat2`. Detection still worked, but those mitigations were not fully attached on this kernel.
- The custom rule is intentionally narrow to reduce noise. It watches a single high-signal path and excludes host events with `container.id != host`.
- The built-in shell rule fired reliably. For the file-write behavior, the custom rule provided deterministic evidence for container drift under `/usr/local/bin/`.

## Task 2 - Policy-as-Code with Conftest

### Kubernetes Manifest Comparison
`juice-unhardened.yaml` is intentionally weak:
- Uses `bkimminich/juice-shop:latest`
- No container `securityContext`
- No CPU or memory requests/limits
- No readiness or liveness probes

`juice-hardened.yaml` satisfies the hardening policy by:
- Pinning the image to `bkimminich/juice-shop:v19.0.0`
- Setting `runAsNonRoot: true`
- Setting `allowPrivilegeEscalation: false`
- Setting `readOnlyRootFilesystem: true`
- Dropping all capabilities
- Adding CPU and memory requests/limits
- Adding readiness and liveness probes

### Conftest Results

Unhardened Kubernetes manifest:
- Result: `30 tests, 20 passed, 2 warnings, 8 failures, 0 exceptions`
- Evidence: `labs/lab9/analysis/conftest-unhardened.txt`

Policy violations and why they matter:
- `container "juice" uses disallowed :latest tag`
  Non-deterministic deployments complicate rollback, auditing, and incident response.
- `container "juice" must set runAsNonRoot: true`
  Running as root increases blast radius after compromise.
- `container "juice" must set allowPrivilegeEscalation: false`
  Extra privilege paths remain available to the process.
- `container "juice" must set readOnlyRootFilesystem: true`
  Runtime tampering and persistence become easier.
- `container "juice" missing resources.requests.cpu`
- `container "juice" missing resources.requests.memory`
- `container "juice" missing resources.limits.cpu`
- `container "juice" missing resources.limits.memory`
  Missing requests and limits weaken scheduling guarantees and allow avoidable resource abuse.

Warnings on the unhardened manifest:
- `container "juice" should define readinessProbe`
- `container "juice" should define livenessProbe`

These remain warnings because they affect resilience and safe rollout behavior more than direct privilege boundaries.

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
- `tmpfs: ["/tmp"]` keeps a writable temp area without making the full filesystem writable

## Files Produced
- `labs/lab9/falco/rules/custom-rules.yaml`
- `labs/lab9/falco/logs/falco.log`
- `labs/lab9/analysis/conftest-unhardened.txt`
- `labs/lab9/analysis/conftest-hardened.txt`
- `labs/lab9/analysis/conftest-compose.txt`
