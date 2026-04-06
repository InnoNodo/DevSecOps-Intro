# Lab 6 Submission - IaC Security Scanning and Comparative Analysis

## Task 1 - Terraform and Pulumi Security Scanning

### Scope and Evidence

Terraform was scanned from `labs/lab6/vulnerable-iac/terraform` with `tfsec`, `Checkov`, and `Terrascan`. Pulumi YAML was scanned from `labs/lab6/vulnerable-iac/pulumi` with `KICS`.

Primary evidence files:

- `labs/lab6/analysis/tfsec-results.json`
- `labs/lab6/analysis/checkov-terraform-results.json`
- `labs/lab6/analysis/terrascan-results.json`
- `labs/lab6/analysis/kics-pulumi-results.json`

### Terraform Tool Comparison

| Tool | Findings | Notable pattern |
|---|---:|---|
| tfsec | 53 | Strong AWS-focused misconfiguration coverage, especially S3, SG, IAM, and encryption |
| Checkov | 78 | Broadest Terraform coverage, especially IAM and operational best practices |
| Terrascan | 22 | Lower total count, but useful policy-oriented findings with readable summaries |

`tfsec` severity breakdown:

| Severity | Count |
|---|---:|
| CRITICAL | 9 |
| HIGH | 25 |
| MEDIUM | 11 |
| LOW | 8 |

`Terrascan` severity breakdown:

| Severity | Count |
|---|---:|
| HIGH | 14 |
| MEDIUM | 8 |

### Pulumi Security Analysis

KICS found 6 issues in the Pulumi YAML manifest.

| Severity | Count |
|---|---:|
| CRITICAL | 1 |
| HIGH | 2 |
| MEDIUM | 1 |
| INFO | 2 |

Detected Pulumi issues included:

- public RDS instance
- unencrypted DynamoDB table
- hardcoded password in configuration
- EC2 instance monitoring disabled
- DynamoDB PITR disabled
- EC2 not EBS optimized

### Terraform vs Pulumi

Terraform HCL produced many more findings than Pulumi YAML in this lab. That was not because Pulumi was secure, but because the Terraform files expose a wider vulnerable surface area and the Terraform scanner ecosystem is much more mature. `tfsec`, `Checkov`, and `Terrascan` all recognized AWS-specific Terraform resources deeply, while the Pulumi run relied on KICS query coverage for Pulumi YAML only.

Terraform also benefited from scanner overlap. The same insecure patterns were independently flagged across tools, especially:

- public database exposure
- unrestricted security groups
- missing encryption
- excessive IAM permissions
- missing backups and hardening controls

Pulumi findings were valid, but KICS coverage was narrower and more selective. It still caught critical issues, especially public RDS and secret exposure, but the total count was much lower than the vulnerability catalog in the lab README.

### KICS Pulumi Support Evaluation

KICS demonstrated that Pulumi YAML is scanable in a practical way and that the Pulumi query catalog is usable for AWS-focused checks. It was effective at:

- public exposure checks
- encryption checks
- secret detection
- selected EC2 and DynamoDB best practices

Its limitations in this lab were:

- lower issue volume than the known vulnerable design suggests
- more selective coverage than Terraform-native scanners
- weaker comparative depth for IAM and broader compliance drift

Conclusion: KICS is a reasonable Pulumi YAML baseline scanner, but for Terraform it is not a substitute for Terraform-specialized tools.

### Critical Findings

#### 1. Publicly accessible RDS instance

- Terraform: `aws_db_instance.unencrypted_db` in `database.tf`
- Pulumi: `unencryptedDb` in `Pulumi-vulnerable.yaml`
- Evidence:
  - `tfsec`: AWS RDS and SG exposure findings
  - `Terrascan`: `RDS Instance publicly_accessible flag is true`
  - `KICS`: `RDS DB Instance Publicly Accessible`

Risk: internet-reachable database endpoints drastically expand the attack surface and make brute force, credential stuffing, and direct exploitation realistic.

Remediation example:

```hcl
publicly_accessible = false
```

#### 2. Wildcard IAM permissions

- Terraform: `aws_iam_policy.admin_policy`
- Terraform: `aws_iam_user_policy.service_policy`
- Terraform: `aws_iam_policy.privilege_escalation`

Risk: `Action = "*"` and `Resource = "*"` create immediate over-privilege and privilege escalation paths.

Remediation example:

```hcl
Action = [
  "s3:GetObject",
  "s3:PutObject"
]
Resource = [
  "arn:aws:s3:::my-bucket/*"
]
```

#### 3. Open security groups and unrestricted ingress

- Terraform: `allow_all`, `ssh_open`, `database_exposed`
- Pulumi: `allowAllSg`, `sshOpenSg`

Risk: unrestricted `0.0.0.0/0` ingress on SSH, RDP, MySQL, PostgreSQL, or all ports allows direct network attack paths.

Remediation example:

```hcl
cidr_blocks = ["10.0.0.0/16"]
```

#### 4. Missing encryption at rest

- Terraform: RDS and DynamoDB
- Pulumi: DynamoDB and EBS

Risk: data theft impact is much worse if storage is readable without strong encryption controls.

Remediation example:

```hcl
storage_encrypted = true
kms_key_id        = aws_kms_key.db.arn
```

#### 5. Hardcoded secrets in IaC and Ansible

- Terraform: provider keys, DB password, API key
- Pulumi: `dbPassword`
- Ansible: passwords in playbooks and inventory

Risk: source control compromise becomes credential compromise. Rotation and access control also become difficult.

Remediation example:

```yaml
db_password: "{{ vault_db_password }}"
```

### Tool Strengths

| Tool | What it excels at |
|---|---|
| tfsec | Fast AWS/Terraform-focused findings, clear severity, strong S3 and network checks |
| Checkov | Broadest Terraform policy coverage, good for compliance and IAM drift |
| Terrascan | Readable policy-style output, useful for governance-oriented review |
| KICS | Cross-framework scanning, especially useful for Pulumi YAML and Ansible secret detection |

## Task 2 - Ansible Security Scanning with KICS

### Ansible Results

KICS found 10 issues in the Ansible content.

| Severity | Count |
|---|---:|
| HIGH | 9 |
| LOW | 1 |

Detected query groups:

- `Passwords And Secrets - Generic Password` with 6 results
- `Passwords And Secrets - Generic Secret` with 1 result
- `Passwords And Secrets - Password in URL` with 2 results
- `Unpinned Package Version` with 1 result

### Key Security Problems

KICS strongly highlighted a real weakness in this Ansible set: secrets are spread across multiple locations.

Examples:

- `deploy.yml` hardcodes `db_password`
- `deploy.yml` embeds credentials in `db_connection`
- `deploy.yml` uses a credentialed Git URL
- `inventory.ini` stores `ansible_password`, `ansible_become_password`, and API secrets in plaintext
- `configure.yml` stores `admin_password` in plaintext

### Best Practice Violations

#### 1. Plaintext credentials in inventory and vars

Impact: anyone with repository access gets infrastructure credentials and privilege escalation material.

Fix:

- move secrets to Ansible Vault or an external secret manager
- remove passwords from inventory
- use short-lived credentials where possible

#### 2. Passwords embedded in URLs

Impact: credentials leak into logs, process lists, and shell history.

Fix:

- use deploy keys, token helpers, or environment-backed auth
- avoid embedding credentials in repository URLs

#### 3. Unpinned package installation with `state: latest`

Impact: builds become non-deterministic and can pull unexpected package versions into production.

Fix:

```yaml
apt:
  name: myapp=1.4.2
  state: present
```

### KICS Ansible Query Evaluation

KICS was strongest on secret detection in this lab. It automatically identified:

- generic passwords
- generic secrets
- passwords embedded in URLs
- one package hardening issue

That is valuable, but it also shows a limitation: many intentionally vulnerable Ansible behaviors in the playbooks were not surfaced by KICS here, such as dangerous shell usage, firewall disabling, weak SSH settings, and insecure file permissions. For Ansible, KICS should be treated as a baseline scanner, not the only control.

### Remediation Steps

- replace plaintext secrets with Ansible Vault or a managed secret store
- remove passwords and private key paths from `inventory.ini`
- replace credentialed repository URLs with token helpers or SSH deploy keys
- pin package versions for repeatable deployments
- add `no_log: true` to sensitive tasks
- replace `shell` and `raw` with purpose-built modules where possible
- harden SSH configuration and avoid root login

## Task 3 - Comparative Tool Analysis and Security Insights

### Tool Comparison Matrix

| Criterion | tfsec | Checkov | Terrascan | KICS |
|---|---|---|---|---|
| Total Findings | 53 | 78 | 22 | 16 total across Pulumi and Ansible |
| Scan Speed | Fast | Medium | Fast | Medium |
| False Positives | Low | Medium | Low-Medium | Low |
| Report Quality | 4/4 | 3/4 | 3/4 | 3/4 |
| Ease of Use | 4/4 | 3/4 | 3/4 | 3/4 |
| Documentation | 4/4 | 4/4 | 3/4 | 3/4 |
| Platform Support | Terraform-focused | Multi-framework | Multi-framework | Multi-framework |
| Output Formats | JSON, text, SARIF | JSON, CLI, JUnit and more | JSON, human | JSON, HTML, CLI |
| CI/CD Integration | Easy | Easy | Medium | Easy |
| Unique Strengths | Excellent Terraform signal-to-noise | Broadest policy coverage | Governance-oriented policy view | Useful cross-IaC scanning, Pulumi YAML and Ansible support |

### Category Analysis

The counts below are approximate category groupings based on actual findings and query names.

| Security Category | tfsec | Checkov | Terrascan | KICS (Pulumi) | KICS (Ansible) | Best Tool |
|---|---:|---:|---:|---:|---:|---|
| Encryption Issues | 21 | 22 | 2 | 1 | 0 | Checkov |
| Network Security | 16 | 17 | 6 | 1 | 0 | Checkov |
| Secrets Management | 0 | 3 | 1 | 1 | 9 | KICS for Ansible, Checkov for Terraform |
| IAM/Permissions | 11 | 23 | 5 | 0 | 0 | Checkov |
| Access Control | 1 | 8 | 2 | 1 | 0 | Checkov |
| Compliance/Best Practices | 4 | 5 | 6 | 2 | 1 | Terrascan for governance-style checks |

### Top 5 Critical Findings

1. Public RDS exposure in both Terraform and Pulumi.
2. Wildcard IAM permissions and privilege escalation paths in Terraform.
3. Security groups open to the world for SSH, RDP, MySQL, PostgreSQL, and all traffic.
4. Missing encryption for RDS, DynamoDB, EBS, and S3-related storage paths.
5. Plaintext secrets spread through Ansible playbooks and inventory.

### Tool Selection Guide

#### If the stack is mostly Terraform

Use `tfsec` and `Checkov` together. `tfsec` gives fast feedback and `Checkov` adds broader compliance and IAM coverage.

#### If the stack mixes Terraform, Pulumi, and Ansible

Use `Checkov` plus `KICS`. KICS is useful because it gives one scanner family across non-Terraform IaC.

#### If governance and policy reporting matter most

Add `Terrascan` for a policy-oriented view and easier mapping into compliance discussions.

### Lessons Learned

- one scanner is not enough for IaC
- Terraform-native tooling is much deeper than generic cross-IaC tooling
- KICS is valuable for frameworks that are otherwise less well covered
- secret detection in Ansible is useful, but behavior-based misconfiguration coverage still needs complementary controls
- report overlap is helpful because repeat findings increase confidence in the result

### CI/CD Integration Strategy

Recommended pipeline:

1. Pre-commit: `tfsec` for fast Terraform feedback.
2. Pull request: `Checkov` on Terraform plus `KICS` on Pulumi and Ansible.
3. Merge gate: fail on critical and high findings unless there is an approved exception.
4. Scheduled governance scan: `Terrascan` for policy drift and compliance reporting.

### Justification

This strategy balances speed, coverage, and operational realism. `tfsec` keeps developer feedback fast. `Checkov` broadens Terraform detection. `KICS` closes framework gaps for Pulumi YAML and Ansible. `Terrascan` adds a governance-oriented control layer. The overlap is intentional: different tools catch different parts of the same insecure design, and that is exactly what a practical DevSecOps pipeline should exploit.
