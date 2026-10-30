provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = "twn-capstone-03"
      Environment = "dev"
      ManagedBy   = "terraform"
      Bootcamp    = "techworld-with-nana"
    }
  }
}
