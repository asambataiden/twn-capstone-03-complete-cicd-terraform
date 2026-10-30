variable "aws_region" {
  description = "AWS region for Capstone 03."
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "asambataiden-dev"
}

variable "aws_account_id" {
  description = "Expected AWS account ID."
  type        = string
}

variable "project_name" {
  description = "Unique prefix for project resources."
  type        = string
  default     = "twn-capstone-03"
}

variable "vpc_cidr" {
  type    = string
  default = "10.83.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.83.1.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "root_volume_size" {
  type    = number
  default = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 50
    error_message = "Root volume size must be between 8 and 50 GiB."
  }
}
