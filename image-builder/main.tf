provider "aws" {
  region = var.aws_region
}

# S3 Bucket
resource "aws_s3_bucket" "image_builder_bucket" {
  bucket = var.bucket_name
   tags = {
    Name = "ImageBuilderLogs"
  }
}

# ECR Repository
resource "aws_ecr_repository" "my_ecr_repo" {
  name = var.ecr_repo_name
}

# IAM Role for EC2 Image Builder
resource "aws_iam_role" "imagebuilder_role" {
  name = "EC2ImageBuilderRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Managed Policies
data "aws_iam_policy" "s3_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
data "aws_iam_policy" "ec2_instance_profile_ecr_container_builds" {
  arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}
data "aws_iam_policy" "ec2_instance_profile_image_builder" {
  arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}
data "aws_iam_policy" "s3_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
data "aws_iam_policy" "ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Managed Policies to EC2 Image Builder Role
resource "aws_iam_role_policy_attachment" "imagebuilder_s3_read_only" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.s3_read_only.arn
}
resource "aws_iam_role_policy_attachment" "imagebuilder_ecr_container_builds" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.ec2_instance_profile_ecr_container_builds.arn
}
resource "aws_iam_role_policy_attachment" "imagebuilder_image_builder" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.ec2_instance_profile_image_builder.arn
}
resource "aws_iam_role_policy_attachment" "imagebuilder_s3_full_access" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.s3_full_access.arn
}
resource "aws_iam_role_policy_attachment" "imagebuilder_ssm_managed_instance_core" {
  role       = aws_iam_role.imagebuilder_role.name
  policy_arn = data.aws_iam_policy.ssm_managed_instance_core.arn
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "image-builder-lambda-policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "imagebuilder:StartImagePipelineExecution",
          "imagebuilder:GetImagePipeline",
          "imagebuilder:DescribeImagePipelines",
          "imagebuilder:ListImagePipelines"
        ]
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = "logs:*"
        Effect = "Allow"
        Resource = "*"
      },
      {
        Action = "cloudwatch:PutMetricData"
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for EC2 Image Builder
resource "aws_iam_instance_profile" "imagebuilder_instance_profile" {
  name = "EC2ImageBuilderInstanceProfile"
  role = aws_iam_role.imagebuilder_role.name
}

# Security Group for EC2 Image Builder allowing RDP
resource "aws_security_group" "imagebuilder_sg" {
  name        = "ImageBuilderSecurityGroup"
  description = "Security group for EC2 Image Builder allowing RDP"
  vpc_id      = var.vpc_id
  # Ingress rules
  ingress {
    description = "Allow RDP access"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Ingress rule for SSH 
  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Image Builder Container Recipe - Windows
resource "aws_imagebuilder_container_recipe" "windows_dockerfile_recipe" {
  name        = "WindowsDockerfileRecipe"
  parent_image = "mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019"
  #platform    = "Windows"
  version     = "1.0.0"
  container_type = "DOCKER"
  target_repository {
    repository_name = aws_ecr_repository.my_ecr_repo.name
    service         = "ECR"
  }
  component {
    component_arn = "arn:aws:imagebuilder:us-east-1:aws:component/ecs-optimized-ami-windows/x.x.x"
  }
  dockerfile_template_data = <<EOF
    FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019 AS build
    WORKDIR /app
    RUN Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.40.1.windows.1/Git-2.40.1-64-bit.exe -OutFile C:/git-installer.exe; \
    Start-Process -Wait -FilePath C:/git-installer.exe -ArgumentList '/VERYSILENT', '/NORESTART'; \
    Remove-Item -Force C:/git-installer.exe
    RUN git clone ${var.source_url}
    RUN msbuild /nologo win-container\AoiAspnet\AoiAspnet.sln /property:Configuration=Release /property:DeployOnBuild=true /property:WebPublishMethod=FileSystem /property:DeployTarget=WebPublish /property:PublishUrl=/pub
    FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS runtime
    WORKDIR /inetpub/wwwroot
    COPY --from=build /pub .
    EXPOSE 80
  EOF
}

# EC2 Image Builder Distribution Configuration
resource "aws_imagebuilder_distribution_configuration" "container_distribution_configuration" {
  name          = "ContainerDistributionConfig"
  description   = "Distribution configuration for Windows Dockerfile based image"
    # Specify distribution settings
  distribution {
    region = var.aws_region
      container_distribution_configuration {
        description = "Distribute Windows Docker images"
        container_tags = ["latest"] 
        target_repository {
          repository_name = aws_ecr_repository.my_ecr_repo.name
          service = "ECR"
        }
  }
  }
}

# EC2 Image Builder Infrastructure Configuration
resource "aws_imagebuilder_infrastructure_configuration" "imagebuilder_config" {
  name            = "ImageBuilderConfig"
  instance_profile_name = aws_iam_instance_profile.imagebuilder_instance_profile.name
  instance_types  = [var.instance_type]  
  subnet_id       = var.subnet_id  
  security_group_ids = [aws_security_group.imagebuilder_sg.id]
  key_pair = var.instance_keypair
  instance_metadata_options {
  http_tokens = "required"
  http_put_response_hop_limit = "3"
  }
  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.image_builder_bucket.bucket
      s3_key_prefix  = "image-builder-logs/"
    }
  }
}

# EC2 Image Builder Pipeline
resource "aws_imagebuilder_image_pipeline" "imagebuilder_pipeline" {
  name          = "ImageBuilderPipeline"
  description   = "Pipeline for building Windows Dockerfile based images"

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imagebuilder_config.arn
  container_recipe_arn = aws_imagebuilder_container_recipe.windows_dockerfile_recipe.arn
  distribution_configuration_arn = aws_imagebuilder_distribution_configuration.container_distribution_configuration.arn
  image_tests_configuration {
    image_tests_enabled = false
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"  # Path to the directory containing your Lambda code
  output_path = "${path.module}/lambda.zip"  # Output path for the ZIP file
}

# Lambda function
resource "aws_lambda_function" "lambda" {
  function_name = "image-builder-lambda"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "${path.module}/lambda.zip"
  environment {
    variables = {
      pipeline_arn = aws_imagebuilder_image_pipeline.imagebuilder_pipeline.arn
    }
  }
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"  # Can be "NONE", or "AWS_IAM" for more security

  # Optionally, you can add a custom domain name if needed (using Route 53 or another DNS provider)
}

resource "aws_lambda_invocation" "invoke_lambda" {
  function_name = aws_lambda_function.lambda.function_name

  # Optionally, pass data to the Lambda function
  input = jsonencode({
    message = "Triggering Lambda after Terraform apply"
  })

  # Ensure this resource runs after the Lambda function URL is created and Image Builder pipeline is set up
  depends_on = [
    aws_lambda_function_url.lambda_url, 
    aws_imagebuilder_image_pipeline.imagebuilder_pipeline
  ]
}

# Output variables
output "ecr_repository_url" {
  value = aws_ecr_repository.my_ecr_repo.repository_url
}
output "lambda_function_url" {
  value = aws_lambda_function_url.lambda_url.function_url
}