### LAMBDA HANDLE NEW INSTANCE ROLE ###

resource "aws_iam_role" "handle_launch_lambda" {
  name = "${var.project_name}-handle-launch-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "handle_launch_lambda" {
  role       = aws_iam_role.handle_launch_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "associate_eip" {
  name        = "${var.project_name}-associate-eip-to-instance"
  path        = "/"
  description = "This policy allows for the EC2 launch instance Lambda to associate the persistent EIP to the new instance on replacement."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Effect = "Allow"
        Resource = [
          aws_ecs_service.minecraft.id,
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/default/${aws_ecs_service.minecraft.name}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "associate_eip" {
  role       = aws_iam_role.handle_launch_lambda.name
  policy_arn = aws_iam_policy.associate_eip.arn
}

### LAMBDA AUTO SAVE ROLE ###

resource "aws_iam_role" "automated_save" {
  name = "${var.project_name}-auto-save-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "automated_save" {
  role       = aws_iam_role.automated_save.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "run_in_vpc" {
  role       = aws_iam_role.automated_save.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

### LAMBDA SEND TEXT ALERTS ROLE ###

resource "aws_iam_role" "public_dns_config_lambda" {
  name = "${var.project_name}-public-dns-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "public_dns_config_lambda" {
  name        = "${var.project_name}-public-dns-config"
  path        = "/"
  description = "This policy allows for the custom minecraft server text alerts logic to execute."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeNetworkInterfaces"]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action   = ["route53:ChangeResourceRecordSets"]
        Effect   = "Allow"
        Resource = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.personal_domain.zone_id}"]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks"
        ]
        Resource = [
          "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task/${aws_ecs_cluster.minecraft.name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "public_dns_config_lambda_basic_execution" {
  role       = aws_iam_role.public_dns_config_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "public_dns_config_lambda" {
  role       = aws_iam_role.public_dns_config_lambda.name
  policy_arn = aws_iam_policy.public_dns_config_lambda.arn
}

### ECS execution role ###

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_basic_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

### ECS task role ###

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Condition = {
          "ArnLike" = {
            "aws:SourceArn" = "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
          }
          "StringEquals" = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_basic_execution" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "ecs_task_efs_perms" {
  name        = "${var.project_name}-efs-access"
  path        = "/"
  description = "This policy allows for the minecraft server to mount the EFS file system."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"]
        Effect   = "Allow"
        Resource = ["arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.account_id}:file-system/${aws_efs_file_system.minecraft.id}"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_efs_perms" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_efs_perms.arn
}
