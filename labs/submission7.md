# Lab 7 Submission - Container Security Scanning and Deployment Hardening

## Task 1 - Image Vulnerability and Configuration Analysis

### Scope and Evidence

Target image: `bkimminich/juice-shop:v19.0.0`.

Evidence files:

- `labs/lab7/scanning/scout-cves.txt`
- `labs/lab7/scanning/dockle-results.txt`
- `labs/lab7/scanning/snyk-results.txt`
- `labs/lab7/hardening/manual-host-image-assessment.txt`

Docker Scout indexed **1004 packages** and detected **55 vulnerable packages**. The overview reported **20 Critical, 79 High, 45 Medium, 8 Low, and 7 Unknown** vulnerabilities. Scout also printed a later total of 159 vulnerabilities found in 55 packages, which appears to include expanded/normalized records beyond the overview table.

Snyk was not executed because no `SNYK_TOKEN` was available in the environment. Dockle was not executed because it requires mounting `/var/run/docker.sock` into a third-party container, which gives broad control of the local Docker daemon. A safer Docker image/host inspection was collected instead.

### Top Critical and High Vulnerabilities

| # | CVE | Package | Severity | Impact |
|---:|---|---|---|---|
| 1 | CVE-2026-44006 | `vm2` 3.9.17 | Critical | Code injection in sandboxing library; possible escape or arbitrary code execution depending on reachable usage |
| 2 | CVE-2026-44005 | `vm2` 3.9.17 | Critical | Prototype pollution can corrupt object behavior and bypass intended isolation |
| 3 | CVE-2026-43997 | `vm2` 3.9.17 | Critical | Code injection risk in a package intended to execute untrusted JavaScript safely |
| 4 | CVE-2026-26332 | `vm2` 3.9.17 | Critical | Protection mechanism failure, weakening sandbox boundaries |
| 5 | CVE-2025-55130 | `node` 22.18.0 | Critical | Runtime-level vulnerability; fix requires upgrading Node to a patched version |

### Configuration Findings

Manual image inspection found:

| Check | Result | Security meaning |
|---|---|---|
| Image user | `65532` | The image is configured to run as non-root, reducing privilege after compromise |
| Entrypoint | `/nodejs/bin/node` | Application runs as Node.js process |
| Exposed port | `3000/tcp` | Expected Juice Shop service port |
| Environment | `PATH`, `SSL_CERT_FILE` | No obvious secret-like environment variable was present in image config |
| Docker daemon security | `seccomp,profile=builtin`; `cgroupns` | Built-in seccomp and cgroup namespace isolation are enabled |

The main configuration risk is not root execution, because this image already uses UID `65532`. The larger risks are vulnerable application/runtime dependencies and the need to constrain the container at runtime with dropped capabilities, `no-new-privileges`, and resource limits.

### Security Posture Assessment

The image has a better-than-default runtime identity because it does not run as root. Recommended improvements:

1. Upgrade `vm2`, Node.js, and other vulnerable dependencies or rebuild from a patched Juice Shop/base image.
2. Pin images by digest for deterministic deployment.
3. Run with `--cap-drop=ALL` and add back only required capabilities.
4. Enable `--security-opt=no-new-privileges`.
5. Set memory, CPU, and PID limits to reduce denial-of-service blast radius.
6. Keep Docker built-in seccomp enabled.

## Task 2 - Docker Host Security Benchmarking

### Evidence

- `labs/lab7/hardening/docker-bench-results.txt`
- `labs/lab7/hardening/manual-host-image-assessment.txt`

The full `docker/docker-bench-security` container was not executed because it requires host-level mounts and privileges: host network, host PID namespace, `audit_control`, read-only `/var/lib`, Docker socket, `/etc`, and systemd directories. That is a valid CIS-style audit pattern, but it gives a third-party container broad host visibility.

Manual host evidence collected from Docker itself:

| Control area | Observed value | Assessment |
|---|---|---|
| Docker version | 29.3.1 | Current enough for modern security features |
| Security options | `seccomp,profile=builtin`; `cgroupns` | Built-in syscall filtering and cgroup namespace support are enabled |
| Cgroup driver | `systemd` | Standard on Linux hosts and suitable for resource governance |
| Docker root dir | `/var/snap/docker/common/var-lib-docker` | Docker Snap storage path in this WSL environment |

### Summary Statistics

Because Docker Bench was not run, PASS/WARN/FAIL/INFO counts are not available from the official benchmark output. The manual evidence confirms two important baseline controls: seccomp is enabled and cgroup namespace isolation is present.

### Remediation Priorities

If running the full CIS benchmark is approved later, I would focus remediation on:

1. Docker daemon hardening and audit logging.
2. Restricting access to `/var/run/docker.sock`.
3. Ensuring containers use non-root users and no unnecessary capabilities.
4. Setting resource limits and restart policies for production workloads.
5. Enforcing image provenance/signature verification in deployment policy.

## Task 3 - Deployment Security Configuration Analysis

### Functionality and Resource Evidence

All three profiles started successfully and returned HTTP 200:

| Profile | HTTP result | Memory observed |
|---|---|---|
| Default | 200 | 165.3 MiB / 7.281 GiB |
| Hardened | 200 | 91.46 MiB / 512 MiB |
| Production | 200 | 102.2 MiB / 512 MiB |

The original lab command used `--security-opt=seccomp=default`, but this Docker environment interpreted `default` as a missing file path. The production run therefore omitted the explicit flag while retaining Docker built-in seccomp, confirmed by `docker info`.

### Configuration Comparison

| Setting | Default | Hardened | Production |
|---|---|---|---|
| Capabilities dropped | none | `ALL` | `ALL` |
| Capabilities added | none | none | `CAP_NET_BIND_SERVICE` |
| Security options | none | `no-new-privileges` | `no-new-privileges` |
| Memory limit | none | 512 MiB | 512 MiB |
| Memory swap | none | 1 GiB default Docker behavior | 512 MiB |
| CPU limit | none | 1 CPU requested | 1 CPU requested |
| PID limit | none | none | 100 |
| Restart policy | no | no | `on-failure` |

### Security Measure Analysis

`--cap-drop=ALL` removes Linux capabilities from the container process. Capabilities split root-like powers into smaller privileges, such as network administration or changing ownership. Dropping all capabilities reduces what an attacker can do after remote code execution. `NET_BIND_SERVICE` allows binding to low-numbered ports; Juice Shop uses port 3000, so it is not strictly needed here, but it demonstrates adding back only a specific capability when required.

`--security-opt=no-new-privileges` prevents a process and its children from gaining additional privileges through setuid binaries or file capabilities. It is usually low-risk for web applications and helps block local privilege escalation paths.

`--memory=512m` and `--cpus=1.0` constrain resource consumption. Without limits, a compromised or buggy container can consume host memory/CPU and affect other workloads. Limits that are too low can cause instability or false outages, so they should be set from observed baseline usage plus headroom.

`--pids-limit=100` limits process creation. It helps contain fork-bomb style denial-of-service attacks where a process repeatedly creates child processes until the host process table is exhausted. The right value depends on normal process count under load.

`--restart=on-failure:3` restarts the service after crashes, but stops after repeated failures. It is safer than `always` for crash loops because `always` can hide persistent faults and create noisy restart storms.

### Critical Thinking Questions

For development, I would use the default or lightly hardened profile. Developers need easier debugging and fewer constraints, while still keeping the image non-root.

For production, I would use the production profile: dropped capabilities, no-new-privileges, memory/CPU/PID limits, restart policy, digest-pinned image, and default seccomp enabled.

Resource limits solve noisy-neighbor and denial-of-service problems. They prevent one container from exhausting the host and affecting unrelated services.

If an attacker exploits the default container, they have a larger runtime capability set and no resource ceilings. In the production profile, capability abuse, privilege gain, fork bombs, and unlimited memory growth are constrained.

Additional hardening I would add:

1. Read-only root filesystem with a writable tmpfs for required temp paths.
2. Explicit non-root `--user` matching the image UID.
3. Network egress controls.
4. Digest pinning and signature verification.
5. Centralized runtime monitoring with Falco or equivalent.
