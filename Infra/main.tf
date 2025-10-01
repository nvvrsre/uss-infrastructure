terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
  }

  backend "s3" {
    bucket         = "ushasreestores-s3-tfstate"
    key            = "ushasreestores/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ushasreestores-s3-tflock"
    encrypt        = true
  }
}

# --- Root AWS provider ---
provider "aws" {
  region = "ap-south-1"
}

# --- Your existing modules (unchanged) ---
module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
  cluster_name = var.cluster_name
}

module "eks" {
  source              = "./modules/eks"
  cluster_name        = var.cluster_name
  eks_role_name       = var.eks_role_name
  node_role_name      = var.node_role_name
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
  node_instance_types = var.node_instance_types
  node_disk_size      = var.node_disk_size
  public_access_cidrs = var.public_access_cidrs
  providers           = { aws = aws } # only aws; no k8s/helm passed in
}

module "rds" {
  source                = "./modules/rds"
  db_name               = var.db_name
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  db_username           = var.rds_username
  db_password           = var.rds_password
  private_subnet_ids    = module.vpc.private_subnet_ids
  db_security_group_ids = [module.vpc.rds_sg_id]
  vpc_id                = module.vpc.vpc_id
}

# --- Read the cluster AFTER module.eks has created it ---
data "aws_eks_cluster" "this" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

# --- Kubernetes provider using AWS CLI exec auth (no kubeconfig needed) ---
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", var.cluster_name,
      "--region", var.aws_region
    ]
  }
}

# # --- Default gp3 StorageClass (created at ROOT) ---
# resource "kubernetes_manifest" "gp3_default_sc" {
#   manifest = {
#     apiVersion = "storage.k8s.io/v1"
#     kind       = "StorageClass"
#     metadata = {
#       name = "gp3-default"
#       annotations = {
#         "storageclass.kubernetes.io/is-default-class" = "true"
#       }
#     }
#     provisioner          = "ebs.csi.aws.com"
#     volumeBindingMode    = "WaitForFirstConsumer"
#     allowVolumeExpansion = true
#     parameters = {
#       type      = "gp3"
#       encrypted = "true"
#     }
#   }

#   # ensure module.eks (incl. EBS CSI add-on) is done first
#   depends_on = [module.eks]
# }
