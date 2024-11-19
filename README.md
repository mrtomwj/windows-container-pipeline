# IaC to create a CI/CD Pipeline for building and deploying Windows Containers in AWS

### Assumptions:
* A destination VPC and subnet already exist in the account
* Either a public subnet or NAT gateway exist to allow outbound internet access
* An ec2 instance keypair has already been created
* On initial deployment, expect some stopped/failed tasks on the ECS service until the first windows container build is complete.  These will drop away once the service is stable.

### This code will build the following:
* EC2 Image builder Pipeline, Infrastructure Config, Distribution Config, and Container Recipe
* Lambda function for triggering the container build
* S3 Bucket for container build logs
* ECR Repo for storing built container images
* IAM Roles for build instance and lambda function
* Security group for build instance
* ECS Cluster, Task Definition, and Service
* IAM Role for task execution
* Security group for container ingress from ALB
* Application load balancer, Listener, and Target Group
* Security group for ALB ingress

### Notes
Please adjust role policies and Security Group ingress rules to match your specific environment needs
Adjust task cpu and memory to match your workload
The Lambda url from the output can be used as webhook to trigger the container build from your app source.


The following source_url can be used for a sample .NET framework 4.8 app:
`https://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@github.com/mrtomwj/win-container.git`
