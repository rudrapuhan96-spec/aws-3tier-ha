data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------
# VPC
# ---------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Public Subnets
# ---------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-${count.index + 1}"
    Tier    = "public"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Private Application Subnets
# ---------------------------------------------------------

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-app-${count.index + 1}"
    Tier    = "application"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Private Database Subnets
# ---------------------------------------------------------

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-db-${count.index + 1}"
    Tier    = "database"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Elastic IPs for NAT Gateways
# One EIP per Availability Zone
# ---------------------------------------------------------

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${count.index + 1}"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# NAT Gateways
# One NAT Gateway per Availability Zone
# ---------------------------------------------------------

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name    = "${var.project_name}-nat-${count.index + 1}"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Public Route Table
# ---------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Tier    = "public"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Public Route Table Associations
# ---------------------------------------------------------

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------
# Private Application Route Tables
# One route table per Availability Zone
# ---------------------------------------------------------

resource "aws_route_table" "private_app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-private-app-rt-${count.index + 1}"
    Tier    = "application"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Private Application Route Table Associations
# ---------------------------------------------------------

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# ---------------------------------------------------------
# Private Database Route Tables
# No Internet Route
# ---------------------------------------------------------

resource "aws_route_table" "private_db" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-private-db-rt-${count.index + 1}"
    Tier    = "database"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Private Database Route Table Associations
# ---------------------------------------------------------

resource "aws_route_table_association" "private_db" {
  count = length(aws_subnet.private_db)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}