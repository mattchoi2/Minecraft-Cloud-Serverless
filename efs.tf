resource "aws_efs_file_system" "minecraft" {
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "${var.project_name}-server-files"
  }
}

resource "aws_efs_mount_target" "minecraft" {
  file_system_id  = aws_efs_file_system.minecraft.id
  subnet_id       = aws_subnet.private[0].id
  security_groups = [aws_security_group.efs_endpoint.id]
}

resource "aws_security_group" "efs_endpoint" {
  name        = "${var.project_name}-efs-endpoint"
  description = "Allow all local traffic within the VPC."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All local traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
