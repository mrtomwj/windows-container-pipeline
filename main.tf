provider "aws" {
  region = var.aws_region
}

module "image_builder" {
  source = "./image-builder"
ecr_repo_name = var.ecr_repo_name
vpc_id = var.vpc_id
subnet_id = var.subnet_id
bucket_name = var.bucket_name
aws_region = var.aws_region
instance_type = var.instance_type
instance_keypair = var.instance_keypair
source_url = var.source_url
}

module "ecs_cluster" {
  source = "./ecs-cluster"
  aws_region = var.aws_region
  cluster_name = var.cluster_name
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  subnet_id2 = var.subnet_id2
  ecr_url = module.image_builder.ecr_repository_url
}
# Output variables
output "lambda_function_url" {
  value = module.image_builder.lambda_function_url
}
output "alb_url" {
  value = module.ecs_cluster.alb_url
}