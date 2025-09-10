resource "aws_db_subnet_group" "this" {
  name       = "${var.db_name}-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "${var.db_name}-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier              = var.db_name
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = 3306
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.db_security_group_ids
  skip_final_snapshot     = true
  publicly_accessible     = false
  storage_encrypted       = true
  apply_immediately       = true

  tags = {
    Name = var.db_name
  }
}
