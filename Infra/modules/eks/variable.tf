variable "cluster_name" {}
variable "eks_role_name" {}
variable "node_role_name" {}
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "node_desired_size" {}
variable "node_max_size" {}
variable "node_min_size" {}
variable "node_instance_types" { type = list(string) }
variable "node_disk_size" {}
variable "public_access_cidrs" { type = list(string) }
