output "instance_id" {
  description = "EC2 instance ID for SSM deployment."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "EC2 public IPv4 address; inbound access remains blocked."
  value       = aws_instance.app.public_ip
}

output "vpc_id" {
  description = "Dedicated Capstone 03 VPC."
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Dedicated Capstone 03 public subnet."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "EC2 security group with no inbound rules."
  value       = aws_security_group.ec2.id
}

output "ssm_start_session_command" {
  description = "Command for an authorized operator to access the instance."
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "ecr_repository_url" {
  description = "Private ECR repository URL for the Capstone 03 application."
  value       = aws_ecr_repository.app.repository_url
}
