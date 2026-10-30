variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "aws_profile" {
  type    = string
  default = "asambataiden-dev"
}

variable "aws_account_id" {
  type = string
}

variable "bucket_name" {
  type = string

  validation {
    condition     = can(regex("^twn-capstone03-tfstate-[0-9]{12}-[a-z0-9-]+$", var.bucket_name))
    error_message = "Use the dedicated Capstone 03 state-bucket naming convention."
  }
}
