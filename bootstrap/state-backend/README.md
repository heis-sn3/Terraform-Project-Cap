# State Backend Bootstrap

This directory provisions the three S3 buckets that will hold Terraform state for dev, qa, and prod environments.

## Chicken-and-egg problem

Terraform state backends require a bucket to exist before `terraform init` can configure the backend. This bootstrap solves that by:

1. Using **local state** (no backend block) to create the three state buckets
2. Providing a script to initialize all environment backends once the buckets exist

## Bucket configuration

Each bucket (`ntombela-sva-s3-{dev,qa,prod}`) includes:
- Versioning enabled
- Server-side encryption (AES256)
- Public access blocked
- `force_destroy = false` + `lifecycle { prevent_destroy = true }`

## Usage

### First-time setup

```bash
cd bootstrap/state-backend
terraform init
terraform apply
```

This creates the three state buckets.

### Initialize project backends

After the buckets exist, run from the repo root:

```bash
./bootstrap/state-backend/init-backends.sh
```

This initializes the main project to use the remote state backends for all three environments.

### Re-applying

Re-running `terraform apply` in this directory is safe and will show "No changes" if the buckets are already configured correctly.

## State isolation

The bootstrap's state is stored **locally** in `bootstrap/state-backend/terraform.tfstate` and is separate from the main project's remote state.
