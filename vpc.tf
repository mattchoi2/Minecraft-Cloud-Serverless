resource "aws_vpc" "main" {
  # 32 IP addresses
  cidr_block           = "10.0.0.0/27"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-network"
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "100.0.0.0/16"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 1, count.index)
  availability_zone       = data.aws_availability_zones.available.names[length(data.aws_availability_zones.available.names) - count.index - 3]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc_ipv4_cidr_block_association.secondary_cidr.cidr_block, 1, count.index)
  availability_zone       = data.aws_availability_zones.available.names[length(data.aws_availability_zones.available.names) - count.index - 3]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
  }
}

resource "aws_security_group" "minecraft_server" {
  name        = var.project_name
  description = "Allow the Minecraft server EC2 spot instance to recieve traffic from Route53."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Minecraft server traffic ports opened"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Allow RCON port traffic for the ECS Minecraft server container from the automated save Lambda."
    from_port       = var.rcon_port
    to_port         = var.rcon_port
    protocol        = "tcp"
    security_groups = [aws_security_group.automated_container_save.id]
  }

  tags = {
    Name = "${var.project_name}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-internet"
  }
}

resource "aws_route" "to_igw" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}
