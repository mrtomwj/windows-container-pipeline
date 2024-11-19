provider "aws" {
  region = var.aws_region 
}

resource "aws_ecs_cluster" "container_cluster" {
  name = var.cluster_name
}

# IAM role for ECS Task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.cluster_name}"

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

resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
  name       = "ecsTaskExecutionPolicyAttachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
}
resource "aws_iam_policy_attachment" "ecr_read-only_policy" {
  name       = "ecrROTaskExecutionPolicyAttachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
}

# Define the Fargate Task Definition
resource "aws_ecs_task_definition" "example_task" {
  family                   = "example-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"  # 1.0 vCPU
  memory                   = "2048"  # 2.0 GB RAM
  runtime_platform {
    operating_system_family = "WINDOWS_SERVER_2019_CORE"
    cpu_architecture = "X86_64"
  }
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "example-container"
      image     = "${var.ecr_url}:latest"
      #memory    = 1024
      #cpu       = 2048
      essential = true
      healthcheck: {
      "command" = ["CMD", "powershell", "-Command", "try { if ((Invoke-WebRequest -UseBasicParsing http://localhost).StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }"]
      "interval"    = 30
      "timeout"     = 5
      "retries"     = 3
      }
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Create an ECS Service using Fargate
resource "aws_ecs_service" "example_service" {
  name            = "example-service"
  cluster         = aws_ecs_cluster.container_cluster.id
  task_definition = aws_ecs_task_definition.example_task.arn
  desired_count   = 1

  launch_type = "FARGATE"
  
  network_configuration {
    subnets          = [var.subnet_id]
    assign_public_ip = true
    security_groups = [aws_security_group.example_sg.id] 
  }
}

# Security group to allow inbound HTTP traffic (port 80)
resource "aws_security_group" "example_sg" {
  name        = "example-sg"
  description = "Allow inbound HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

