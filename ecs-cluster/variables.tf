variable "aws_region" {
  description = "Enter the AWS region"
  type        = string
}
variable "cluster_name" {
  description = "Enter a Name for the ECS Cluster"
  type        = string
}
variable "vpc_id" {
  description = "Enter the VPC ID where Tasks will be launched"
  type        = string
}
variable "subnet_id" {
  description = "Enter the subnet ID where Tasks will be launched"
  type        = string
}
variable "subnet_id2" {
  description = "Enter a second subnet ID for ALB"
  type        = string
}
variable "ecr_url" {
  description = "Enter the Url for the ECR Repository"
  type        = string
}
