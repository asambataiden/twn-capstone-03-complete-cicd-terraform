output "state_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "Dedicated Capstone 03 Terraform remote-state bucket."
}

output "state_bucket_region" {
  value       = var.aws_region
  description = "AWS region containing the state bucket."
}
