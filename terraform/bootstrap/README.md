# Terraform remote state bootstrap

Create an S3 bucket dedicated to this assessment before initializing the environment backend. Enable versioning, server-side encryption, public-access blocking, and least-privilege access. Terraform's S3 backend supports native state locking with `use_lockfile = true` in recent Terraform versions; a DynamoDB lock table is an alternative for compatible setups. Never commit state or plan files.

Example backend block for `terraform/environments/dev/backend.tf` after the bucket exists:

```hcl
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_UNIQUE_STATE_BUCKET"
    key          = "taskflow/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Bootstrap the bucket separately and protect it from accidental destruction. Do not put AWS credentials in this file.
