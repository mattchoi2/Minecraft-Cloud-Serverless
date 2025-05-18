resource "aws_efs_file_system" "minecraft" {
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "${var.project_name}-server-files"
  }
}

resource "aws_efs_mount_target" "minecraft" {
  count           = length(aws_subnet.public)
  file_system_id  = aws_efs_file_system.minecraft.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs_endpoint.id]
}

resource "aws_efs_access_point" "minecraft" {
  file_system_id = aws_efs_file_system.minecraft.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/minecraft"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.project_name}-access-point"
  }
}

resource "aws_security_group" "efs_endpoint" {
  name        = "${var.project_name}-efs-endpoint"
  description = "Allow NFS traffic for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NFS traffic"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
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
