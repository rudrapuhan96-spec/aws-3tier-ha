# ---------------------------------------------------------
# RDS DB Subnet Group
# ---------------------------------------------------------

resource "aws_db_subnet_group" "mysql" {
  name = "${var.project_name}-db-subnet-group"

  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Tier    = "database"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# RDS MySQL Database
# ---------------------------------------------------------

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = "admin"

  manage_master_user_password = true

  port = 3306

  db_subnet_group_name = aws_db_subnet_group.mysql.name

  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  publicly_accessible = false

  multi_az = true

  backup_retention_period = 1

  backup_window = "18:00-19:00"

  maintenance_window = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true

  deletion_protection = false

  skip_final_snapshot = true

  tags = {
    Name    = "${var.project_name}-mysql"
    Tier    = "database"
    Project = var.project_name
  }
}