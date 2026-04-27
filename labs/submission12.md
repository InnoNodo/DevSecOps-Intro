# Lab 12 Submission — Kata Containers: VM-backed Container Sandboxing

## Environment
- **Host OS**: Ubuntu 24.04 (WSL2 on Windows)
- **Kernel**: 6.6.87.2-microsoft-standard-WSL2
- **CPU**: AMD Ryzen 9 8945HX with Radeon Graphics
- ** virtualization**: Not available (WSL2 nested Virtualization disabled)

---

## Task 1 — Kata Installation (2 pts)

### Kata Shim Installation
```
Shim Version: Kata Containers containerd shim (Golang): id: "io.containerd.kata.v2", version: 3.29.0
```

Installed files:
- `/opt/kata/bin/containerd-shim-kata-v2` (67MB)
- QEMU, Firecracker, Cloud Hypervisor
- Guest kernel components

### Configuration
- containerd configured with Kata runtime `io.containerd.kata.v2`
- Kata configuration at `/opt/kata/share/defaults/kata-containers/configuration.toml`

### Limitation
**Kata Containers require nested virtualization** (Intel VT-x or AMD-V) to run VMs. In this WSL2 environment, nested virtualization is disabled, preventing Kata VMs from starting. The shim is installed but cannot create Kata containers.

---

## Task 2 — Run and Compare Containers (3 pts)

### runc (Docker/Containerd default)
```
Host kernel: 6.6.87.2-microsoft-standard-WSL2
Container kernel: 6.6.87.2-microsoft-standard-WSL2 (SHARED with host)
Container CPU: AMD Ryzen 9 8945HX with Radeon Graphics
```

### Key Finding: Kernel Comparison
- **runc**: Uses host kernel directly (same as `uname -r`)
- **Kata**: Would use separate guest kernel (Kata provides isolated VM kernel)

### Isolation Implications
- **runc**: Shares host kernel → kernel vulnerabilities affect all containers
- **Kata**: Separate VM kernel → strong isolation boundary

---

## Task 3 — Isolation Tests (3 pts)

### /proc Filesystem Visibility
| Metric | Host | Container (runc) |
|-------|------|------------------|
| /proc entries | 236 | 64 |
| Kernel modules | 206 | 206 |

### Observations
- runc containers see filtered /proc (64 entries vs host 236)
- Kernel modules visible in containers (206) — containers share host kernel
- No access to host dmesg in containers (isolation)

### Network Interfaces
- Docker uses host networking with NAT
- Kata would create isolated VM network stack

### Security Implications
- **Container escape (runc)**: Full host kernel access, can escape to host
- **Container escape (Kata)**: Confined to VM, need VM hypervisor escape

---

## Task 4 — Performance Snapshot (2 pts)

### Startup Time
```
runc (Docker): ~1.2s
Kata: Would be 3-5s (VM boot overhead)
```

### Overhead Analysis
- **Startup**: Kata slower due to VM boot vs container process
- **Runtime**: Minimal CPU overhead once running
- **Memory**: Kata uses more (VM management)

### HTTP Latency
Juice Shop tested via Docker:
```
HTTP/1.1 200 OK
avg latency: ~3ms (10 samples)
```

---

## Recommendations

### Use runc when:
- Performance critical workloads
- Trusted code that doesn't need strong isolation
- Development/testing

### Use Kata when:
- Untrusted workloads requiring strong isolation
- Multi-tenant environments
- Security-sensitive applications

---

## Summary

| Criterion | Status |
|-----------|-------|
| Task 1 — Kata Install | ✅ Shim installed (VM unavailable) |
| Task 2 — Runtime Compare | ✅ Documented via Docker |
| Task 3 — Isolation Tests | ✅ /proc/module differences |
| Task 4 — Performance | ✅ Startup measured |

**Note**: This environment (WSL2) does not support nested virtualization required for Kata VMs. The Kata shim and assets are fully installed and configured, but cannot execute containers due to hardware virtualization being disabled in the host.