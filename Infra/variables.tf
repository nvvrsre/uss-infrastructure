variable "aws_region" { default = "ap-south-1" }
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}
variable "cluster_name" { default = "ushasreestores-eks" }

variable "eks_role_name" { default = "ushasreestores-eks-role" }
variable "node_role_name" { default = "ushasreestores-node-role" }
variable "node_desired_size" { default = 3 }
variable "node_max_size" { default = 5 }
variable "node_min_size" { default = 2 }
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_disk_size" { default = 30 }
variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "db_name" { default = "ushasreestoresdb" }
variable "rds_instance_class" { default = "db.t3.micro" }
variable "rds_allocated_storage" { default = 20 }
variable "rds_username" { default = "ushasreestores" }
variable "rds_password" { default = "ushasreestores123" }
