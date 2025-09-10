# 🚀 UshaSree Stores Cloud Infrastructure — Terraform Monorepo

## 1️⃣ Overview

This repository contains secure, production-grade, modular Terraform code to provision a **highly available AWS infrastructure** for UshaSree Stores (or any cloud-native app).  
It’s built for **99.95% uptime, security, and cost optimization**—ready for real-world DevSecOps and SRE work.

---

## 2️⃣ Structure & What Each Folder/File Does

```
Infra/
│
├── main.tf           # Calls all modules: VPC, EKS, RDS, S3
├── variables.tf      # All input variables with defaults/types
├── outputs.tf        # Outputs for chaining, CI/CD, documentation
├── providers.tf      # AWS provider and backend S3+lock config
├── terraform.tfvars  # (Optional) Your custom variable overrides
│
├── modules/
│   ├── vpc/          # VPC, subnets, NAT, IGW, route tables
│   ├── eks/          # EKS cluster, IAM, node groups, outputs
│   ├── rds/          # MySQL RDS DB, security, subnet group
│   └── s3/           # S3 bucket for app data (not state)
│
└── bootstrap/        # S3 bucket + DynamoDB for remote backend
```

---

## 3️⃣ Pre-requisites & Bootstrapping (State Storage)

**You MUST create the backend first (once per AWS account):**

1. `cd bootstrap/`
2. Set bucket/table names in variables (`bucket_name`, `lock_table`)
3. `terraform init && terraform apply`

_Note: This creates the S3 and DynamoDB tables for Terraform state/lock (**do this before main infra!**)._

---

## 4️⃣ Main Infra: How to Deploy

**Step 1:** Configure/override variables  
Edit `variables.tf` for defaults, or create a `terraform.tfvars` file:

```hcl
db_password    = "SuperSecurePass!"
s3_bucket_name = "my-company-ushasree-app"
```
> **Never commit secrets. Use env vars or a secure tfvars for prod.**

**Step 2:** Initialize and apply

```bash
terraform init      # Downloads modules, sets up backend
terraform plan      # Shows what will change
terraform apply     # Provisions everything!
```

---

## 5️⃣ Where to Change What

| Need to Change           | File/Module        | How/Why                                                           |
|------------------------- |--------------------|-------------------------------------------------------------------|
| AWS Region               | `variables.tf`     | Change `aws_region` variable.                                     |
| VPC CIDR, AZs            | `variables.tf`     | `vpc_cidr`, `azs` (list of availability zones).                   |
| EKS Cluster settings     | `main.tf` + `variables.tf` | Update `module "eks"` block, e.g. `node_desired_size`.     |
| Database credentials     | `terraform.tfvars` | `db_username`, `db_password`, `db_name`.                          |
| RDS DB instance size     | `main.tf`/`modules/rds` | `db_instance_class`, `allocated_storage`, `multi_az`.    |
| S3 bucket name           | `terraform.tfvars` | `s3_bucket_name` variable.                                        |
| Security Groups/Access   | `modules/vpc/`     | Edit for ingress/egress rules as needed.                          |
| Bootstrap backend names  | `bootstrap/variables.tf` | S3/DynamoDB state infra.                                   |

---

## 6️⃣ Example: Changing EKS Node Type/Size

In your `main.tf`:

```hcl
module "eks" {
  # ...
  node_instance_types = ["t3.medium"]   # Change to t3.large, m5.large, etc
  node_disk_size      = 50              # Change disk size in GB
  node_desired_size   = 2               # Number of worker nodes by default
  # ...
}
```

Or override via `terraform.tfvars` or CLI.

---

## 7️⃣ Security, HA, and Cost Notes

- **All subnets, security groups, and S3 buckets** are created **private by default** (no public access).
- **EKS/RDS** are always placed in private subnets for security.
- **Multi-AZ** (across three AZs by default) for true HA.
- **State is encrypted, versioned, and locked** in backend.
- **Cost tips:** Use spot instances for EKS node groups, set RDS backups/lifecycle S3 rules.

---

## 8️⃣ Outputs

After `terraform apply`, see:

- VPC ID
- EKS cluster name/kubeconfig endpoint
- RDS DB endpoint, port, name
- S3 bucket ARN and name

All outputs are defined in `outputs.tf` for use in CI/CD or documentation.

---

## 9️⃣ How to Destroy Safely

```bash
terraform destroy
```
- Destroys everything except S3 state/lock (do that from `bootstrap/` if needed).
- Always check plan and outputs before destroy.

---

## 🔟 Troubleshooting & Interview Q/A

**Q: What if I lose the state file?**  
A: With S3 versioning, you can roll back. If S3 is deleted, you must `terraform import` every resource (painful).

**Q: How to manage secrets?**  
A: Use AWS Secrets Manager/SSM; avoid hardcoding. Reference in `.tfvars` or as env var `TF_VAR_db_password`.

**Q: How to use this repo for multiple environments?**  
A: Use workspaces (`terraform workspace new dev`), or separate backends (`dev.tfstate`, `prod.tfstate`), or folders.

**Q: What if I see “lock” errors?**  
A: Wait for current run to finish, or (if truly stuck) `terraform force-unlock <lock-id>`.

---

## 1️⃣1️⃣ Example `terraform.tfvars` (for local, never commit to Git)

```hcl
aws_region      = "ap-south-1"
db_username     = "ushasreestore"
db_password     = "StrongPassword2025"
s3_bucket_name  = "my-company-ushasree-app"
```

---

## 1️⃣2️⃣ Module Structure and Customization

Each module (`modules/vpc`, `modules/eks`, `modules/rds`, `modules/s3`) has:

- `main.tf`: All resources (VPC, subnets, cluster, etc)
- `variables.tf`: Module-specific variables (input/output)
- `outputs.tf`: Module-specific outputs

**Edit these files if you need advanced customizations.**

---

## 📚 Pro Interview Tip

Be ready to explain **WHY** you modularized, how you handle failure (state, drift), and security.  
Show you know **state is precious**—and you can always recover from disaster (thanks to S3 versioning and Terraform import).

---

**Prepared by Vishnuvardhan & Mentor (ChatGPT) – 2025**

---

