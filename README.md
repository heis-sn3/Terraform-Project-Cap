# Multi-Environment EKS on Terraform

This repository provisions Amazon EKS clusters across three environments (dev, qa, prod) in the `af-south-1` region using Terraform with independent remote state and DRY modules.

## Overview

- **3 environments**: dev, qa, prod — each with its own EKS cluster, node group, and remote state
- **DRY modules**: `modules/capitec_eks` (cluster + nodes) and `modules/capitec_s3` (buckets)
- **Shared networking**: References the existing default VPC + 3 pre-existing subnets via data sources
- **Remote state**: S3 backend with native file-based locking (Terraform ≥1.10 `use_lockfile`)
- **State buckets**: `force_destroy=false`, so `terraform destroy` refuses to delete a non-empty state bucket
- **Independent deploy/destroy**: Each environment can be managed separately via the Makefile
- **One entrypoint**: Every operation — setup, bucket creation, plan/apply/destroy — runs through `make`

## Architecture

### Naming Convention
All resources follow `ntombela-sva-{resource}-{environment}` pattern:
- EKS clusters: `ntombela-sva-eks-dev`, `ntombela-sva-eks-qa`, `ntombela-sva-eks-prod`
- State buckets: `ntombela-sva-s3-dev`, `ntombela-sva-s3-qa`, `ntombela-sva-s3-prod`

### Networking
- **Default VPC**: `vpc-0be33c9ef19e5520a` (the account's default VPC, resolved at plan time via `data.aws_vpc.default` — not hardcoded)
- **Subnets**: 3 existing public `/24` subnets, one per AZ, selected by CIDR from `project.conf`:
  - `172.31.116.0/24` (af-south-1a)
  - `172.31.117.0/24` (af-south-1b)
  - `172.31.118.0/24` (af-south-1c)
- **Shared, volatile VPC**: this is a training account whose default VPC is shared with other learners, who create/delete subnets freely. If a fresh `apply` errors with *"no matching EC2 Subnet found"*, a chosen CIDR was deleted — re-check with `aws ec2 describe-subnets` and update `SUBNET_CIDRS` in `project.conf`.
- **Trade-off**: All 3 environments share the same subnets — no network isolation between dev/qa/prod

### EKS Configuration
- **Version**: 1.37 (latest available in af-south-1)
- **Node instance type**: t3.small (smallest EKS-viable type, ~11 max pods)
- **Node sizing (identical in every env)**: min=1, max=2, desired=1, max_unavailable=1
- **Capacity type**: SPOT in all three environments
- **Access**: API-based authentication mode with EKS access entries (no aws-auth ConfigMap)
- **Public-IP nodes**: a launch template (`associate_public_ip_address = true`, carrying the cluster SG) is wired into the node group, so worker nodes get public IPs regardless of the subnet's auto-assign setting — the NodePort demo is reachable directly on a node IP
- **NodePort**: Security group rule allows inbound traffic on port 30007 for the nginx demo

#### Decision: uniform SPOT sizing across dev/qa/prod
This is a **training** project, so we deliberately dropped the earlier
per-environment variance (dev=1/SPOT, qa=2/SPOT, prod=2/ON_DEMAND) in favour of a
single, identical node profile everywhere:

| Setting | Value | Why |
|---|---|---|
| `instance_types` | `["t3.small"]` | Smallest EKS-viable node; enough for the demo |
| `capacity_type` | `SPOT` | **Changed prod from ON_DEMAND → SPOT** to minimise training cost; interruptions are acceptable here |
| `node_min` / `node_max` / `node_desired` | 1 / 2 / 1 | Start with one node, allow burst to two; keeps a quiet env cheap |
| `max_unavailable` | 1 | Simple rolling updates for a single-node group |

**Trade-off**: SPOT in "prod" means prod is not representative of a real
production HA posture — acceptable because this environment exists to practise
the multi-env workflow, not to run production workloads. To make prod
production-like again, set `ENV_prod` in `project.conf` back to
`ON_DEMAND` with a higher node count and run `make configure`.

## Prerequisites

1. **Terraform**: ≥1.10 (local version: 1.16.4)
2. **AWS credentials**: Configured via `aws configure` or environment variables
3. **AWS Account**: Training account in `af-south-1`
4. **GitHub**: (Optional) For CI/CD via GitHub Actions

## Bootstrap (One-time Setup)

### The bootstrapping problem (chicken-and-egg)
Each environment stores its state in an **S3 bucket** — but that bucket is itself
infrastructure that has to be created *before* Terraform can use it as a backend.
You can't store the state of "create the state bucket" in the state bucket that
doesn't exist yet. This repo solves it the standard way: a **separate mini-stack**
(`bootstrap/state-backend/`) creates the three buckets using **local state** (kept in
`.state-bootstrap/`, gitignored), and only then do the per-env backends point at those
buckets. `make bootstrap` runs that stack for you.

The per-env backends point at S3 buckets that must exist **before** `make plan`/`apply`
can run. `make bootstrap` creates them. If you've edited `project.conf` (owner, region,
sizing), run `make configure` first to regenerate the env files from it.

```bash
make configure   # (only if you changed project.conf) regenerate envs/*/ from project.conf
make bootstrap    # create the 3 S3 state buckets + init all env backends
```

`make bootstrap`:
1. Creates a hidden `.state-bootstrap/` directory to store the bootstrap's local state
2. Creates the 3 S3 state buckets: `ntombela-sva-s3-{dev,qa,prod}` — each with versioning,
   AES256 encryption, public-access block, and `force_destroy=false`
3. Initializes the project backends for all environments

**Note**: The bootstrap state is stored in `.state-bootstrap/terraform.tfstate` (gitignored).

### (Optional) GitHub OIDC for CI

Only needed if using GitHub Actions. Applied manually once (local state):

```bash
cd bootstrap/github-oidc
terraform init
terraform apply -var="github_org=<your-org>" -var="github_repo=<your-repo>"
```

This creates an IAM role for GitHub Actions to assume via OIDC (no long-lived credentials).

## Usage

All operations run through the **Makefile**, which automatically:
- Initializes the correct backend for the target environment
- Passes the correct var-file
- Wraps the bootstrap/teardown scripts so you never call them directly

Run `make help` to list every target.

### Format & Validate

```bash
make fmt        # Format all .tf files
make validate   # Validate without backend
```

### Plan

```bash
make plan ENV=dev    # Plan dev changes
make plan ENV=qa     # Plan qa changes
make plan ENV=prod   # Plan prod changes
```

Default environment is `dev` if `ENV` is not specified.

### Apply

```bash
make apply ENV=dev    # Deploy dev
make apply ENV=qa     # Deploy qa
make apply ENV=prod   # Deploy prod
```

**⚠️ Cost**: `apply` creates real EKS clusters + EC2 nodes (~$0.10/hr per cluster plus node cost). Destroy what you're not using (`make destroy ENV=<env>`).

### Destroy

Destroy a single environment:

```bash
make destroy ENV=dev    # Destroy dev infrastructure
make destroy ENV=qa     # Destroy qa infrastructure
make destroy ENV=prod   # Destroy prod infrastructure
```

Destroy all environments at once (clusters only — keeps the state buckets):

```bash
make destroy-all    # interactive confirmation; prompts before destroying every env
```

Then, to also remove the S3 state buckets (after `make destroy-all`):

```bash
make destroy-state
```

**Note**: `destroy-state` only succeeds if the buckets are empty, since they use
`force_destroy=false`. Remove any remaining state/lock objects first if needed.

### Output

```bash
make output    # Show outputs for current backend
```

### Clean

```bash
make clean    # Remove .terraform/ directory and plan files
```

## Connecting to EKS

After applying an environment:

```bash
aws eks update-kubeconfig --name ntombela-sva-eks-dev --region af-south-1
kubectl get nodes
```

Replace `dev` with `qa` or `prod` as needed.

## Demo Application

A sample nginx deployment with NodePort service is provided:

```bash
kubectl apply -f k8s/nginx.yaml
```

This creates:
- A Pod running nginx
- A NodePort Service exposing port 80 → 30007

Access it via any node's public IP on port 30007:
```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
curl http://${NODE_IP}:30007
```

## State Locking

All backends use Terraform ≥1.10 native S3 locking via `use_lockfile=true`:
- Lock files are stored as `.tflock` objects in the state bucket during operations
- No DynamoDB table required
- Prevents concurrent modifications to the same environment

## CI/CD (GitHub Actions)

The workflow (`.github/workflows/terraform.yml`) runs:
1. **On PR**: fmt/validate + plan for all 3 environments (posts plans as PR comments)
2. **On push to main**: apply the changed environment(s)
3. **Manual dispatch**: plan/apply/destroy any environment on demand

Currently uses static AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).

**T11** (final task): Switch to OIDC authentication using the bootstrap role.

### Configuration vs. identity (where values come from)

| Value | Kind | Local source | CI source |
|---|---|---|---|
| AWS credentials | secret | `~/.aws` / env | GitHub secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |
| `prefix`, `owner`, `app_name` | identity | exported `TF_VAR_*` by the Makefile (from `project.conf`) | GitHub secrets `TF_VAR_PREFIX` / `TF_VAR_OWNER` / `TF_VAR_APP_NAME` |
| region, env, sizing, subnets, eks version | config | generated `envs/*/*.tfvars` + `*.tfbackend` (from `project.conf`) | same generated files |

Identity (`prefix`/`owner`/`app_name`) is **never written to a tfvars file**. It is
injected as `TF_VAR_*` environment variables: the Makefile exports them from
`project.conf` for local runs, and CI supplies them from GitHub secrets. Because the
Makefile uses `?=`, a value already present in the environment (a CI secret) wins over
`project.conf`. Everything else is non-sensitive config and lives in the generated
per-env files (see *The `.tfbackend`/`.tfvars` files are generated*).

Required GitHub secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`TF_VAR_PREFIX`, `TF_VAR_OWNER`, `TF_VAR_APP_NAME`.

### The `.tfbackend` / `.tfvars` files are generated

`project.conf` is the **single source of truth**. The per-env files under `envs/*/` are
**build artifacts** produced by `make configure` (via `scripts/configure.sh`) — you edit
`project.conf`, never the generated files:

```
project.conf ──(make configure)──► envs/<env>/<env>.tfbackend   (bucket, key, region, lock)
                                    envs/<env>/<env>.tfvars      (env, region, sizing, subnets)
```

Terraform backend blocks can't take variables, so generating the `.tfbackend` files is how
the backend stays DRY. Cloning this project for a different owner/region/sizing is a
**one-file change** in `project.conf` followed by `make configure`.

### Safety: you can't apply dev against prod

- **ENV guard**: the Makefile rejects anything but `dev|qa|prod` (`make apply ENV=staging` → hard error).
- **Separate backends**: each env's state lives in its own bucket + key, selected by `ENV`.
- **Isolated working dirs**: each env inits into its own `.terraform-<env>/`, so environments never share provider/backend state and can even run **concurrently** (`make apply ENV=qa & make apply ENV=prod`).
- **Idempotency**: a second `make apply` with no config change reports *No changes*.

## Repository Structure

```
.
├── Makefile                      # One-command wrapper for all Terraform operations
├── README.md                     # This file
├── project.conf                  # ★ SINGLE SOURCE OF TRUTH (prefix, region, subnets, sizing)
├── providers.tf                  # AWS provider + backend "s3" {} declaration
├── locals.tf                     # Shared tags (DEVELOPER, ENVIRONMENT, etc.)
├── variables.tf                  # Root-level variable declarations
├── main.tf                       # Module instantiation (wires root vars → eks module)
├── outputs.tf                    # Root outputs — re-exports the eks module ARNs per env
├── scripts/                      # Wrapped by the Makefile — not called directly
│   ├── lib.sh                      # Shared helpers: loads project.conf, naming, -var builder
│   ├── configure.sh                # Regenerate envs/*/ from project.conf (make configure)
│   ├── bootstrap-state-buckets.sh  # Create buckets + init backends (make bootstrap)
│   └── destroy-all.sh              # Destroy all environments at once (make destroy-all)
├── bootstrap/
│   ├── github-oidc/              # GitHub Actions OIDC role (local state, manual apply)
│   └── state-backend/            # State-bucket mini-stack (local state, solves bootstrapping)
├── modules/
│   ├── capitec_eks/              # EKS cluster + node group + IAM + SG + launch template + outputs
│   └── capitec_s3/               # Reusable S3 bucket (versioning/encryption/PAB) + outputs
├── envs/                         # ⚙️ GENERATED by `make configure` — do not edit by hand
│   ├── dev/{dev.tfbackend,dev.tfvars}
│   ├── qa/{qa.tfbackend,qa.tfvars}
│   └── prod/{prod.tfbackend,prod.tfvars}
├── k8s/
│   └── nginx.yaml                # Demo nginx Pod + NodePort Service (port 30007)
├── .state-bootstrap/             # Hidden dir for bootstrap local state (gitignored)
├── .terraform-<env>/             # Per-env working dir, isolates state/providers (gitignored)
└── .github/
    └── workflows/
        ├── terraform.yml         # CI: fmt/validate/plan/apply
        └── terraform-destroy.yml # CI: parallel destroy across envs
```

## Assumptions & Limitations

### Networking
- **Shared subnets**: All 3 environments use the same 3 subnets — no true network isolation
- **Default VPC**: Uses the existing default VPC — not a dedicated VPC per environment
- **No subnet management**: Subnets are data-sourced, not created/managed by this code
- **No ELB tags**: Shared subnets are not tagged with `kubernetes.io/cluster/*` or `kubernetes.io/role/elb` — LoadBalancer Services will require manual subnet tagging

### Cost & Sizing
- **Same profile everywhere**: All envs use t3.small, SPOT, min=1/max=2/desired=1 (training decision — see *Decision: uniform SPOT sizing*)
- **SPOT in all envs**: Cheapest option, but nodes can be interrupted — not production-grade HA
- **"prod" is not production-like**: Intentionally identical to dev/qa for this training exercise

### State & Locking
- **Requires TF ≥1.10**: Native S3 locking is not available in older Terraform versions
- **Lock files in S3**: `.tflock` objects appear during operations and are automatically cleaned up
- **No state versioning in code**: While S3 versioning is enabled, there's no automated state rollback mechanism

### Deletion Protection
- **State buckets**: `force_destroy=false` means `terraform destroy` (via `make destroy-state`) refuses to delete a bucket that still holds state/lock objects — empty them first
- **No lifecycle `prevent_destroy`**: removed so the buckets can be torn down through `make destroy-state`; nothing else is hard-protected

## Troubleshooting

### "Backend configuration changed"
Run `make init ENV=<env>` to reconfigure.

### "Error acquiring state lock"
Another operation is in progress. Wait for it to complete, or if stuck, remove the `.tflock` object from S3.

### "Bucket does not exist"
The state buckets haven't been created yet. Run `make bootstrap`.

### Plan shows unexpected subnet IDs
The data sources resolve the real subnet IDs at plan time. Verify the CIDRs in the tfvars match the actual subnets.

## Evidence & Submission

After deploying dev:
1. Run `kubectl apply -f k8s/nginx.yaml`
2. Capture `curl http://<node-ip>:30007` output
3. Take screenshots of independent plan/apply per environment
4. Submit evidence bundle as per training requirements

## The Scripts

Everything in `scripts/` is wrapped by the Makefile — you normally never call these
directly — but here's what each one does. They all derive their values from
`project.conf`, so nothing is hardcoded.

| Script | Invoked by | What it does |
|---|---|---|
| `lib.sh` | *sourced by the others* | Locates the repo root, loads `project.conf`, and exposes the shared helpers: `bucket_name`/`cluster_name` (naming conventions), `environments_hcl` (env list as an HCL literal), and `bootstrap_tf_vars` (the `-var` flags for the bootstrap stacks). The single place naming + config live for the shell side. |
| `configure.sh` | `make configure` | Regenerates `envs/<env>/<env>.tfbackend` and `envs/<env>/<env>.tfvars` from `project.conf`. Idempotent — the generated files are build artifacts. Run it after editing `project.conf`. Deliberately does **not** write `prefix`/`owner`/`app_name` (those are injected as `TF_VAR_*`). |
| `bootstrap-state-buckets.sh` | `make bootstrap` | Solves the chicken-and-egg: creates the hidden `.state-bootstrap/` local state, applies `bootstrap/state-backend/` to create the S3 state buckets (passing `bootstrap_tf_vars`), then runs `terraform init` for each env backend. Run once per account. |
| `destroy-all.sh` | `make destroy-all` | Tears down every environment's cluster (loops `make destroy ENV=<env>`) with an interactive confirmation. Leaves the state buckets — remove those with `make destroy-state`. |

## Authors

- Developer: ntombela-sva
- Owner: Geeks4Learning
- App: capitec-terraform-training

## License

Internal training project — Capitec Bank / Geeks4Learning.

---

> *Ashen one, hearest thou my voice still? Thou hast traversed the three realms — dev, qa, and prod — kindled each cluster, and returned the flame without drift. For thy patience at the bonfire of `terraform apply`, I offer only thanks. Praise the `make`, and may thy state ever remain locked.* 🔥
>
> \[T]/
