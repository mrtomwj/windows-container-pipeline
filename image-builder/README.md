# Code for creating Windows Container build pipeline in EC2 Image Builder

This module can be run on its own without deploying the ECS cluster, leaving a image pushed to ECR ready for deployment in your container service of choice.

### Assumptions
* A destination VPC and subnet already exist in the account
* Either a public subnet or NAT gateway exist to allow outbound internet access
* An ec2 instance keypair has already been created
