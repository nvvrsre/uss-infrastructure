variable "db_name" {}
variable "instance_class" { default = "db.t3.micro" }
variable "allocated_storage" { default = 20 }
variable "db_username" {}
variable "db_password" {}
variable "private_subnet_ids" { type = list(string) }
variable "db_security_group_ids" { type = list(string) }
variable "vpc_id" {}
