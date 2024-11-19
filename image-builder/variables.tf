variable "bucket_name" {
  description = "Enter the name of the S3 bucket for project"
  type        = string
}
variable "source_url" {
  description = "Enter url for source code"
  type = string
}
variable "aws_region" {
  description = "Enter the AWS region"
  type        = string
}
variable "ecr_repo_name" {
  description = "Enter a name for the ECR repository"
  type        = string
}
variable "vpc_id" {
  description = "Enter the VPC ID where EC2 instances will be launched"
  type        = string
}
variable "subnet_id" {
  description = "Enter the subnet ID where EC2 instances will be launched"
  type        = string
}
variable "instance_type" {
  description = "Enter the EC2 instance type for Image Builder"
  type        = string
}
variable "instance_keypair" {
  description = "Enter name of EC2 keypair for build instance"
  type = string
}
