provider "aws" {
  region  = "ap-southeast-2"
  profile = "dev"
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Terraform   = "true"
      Project     = var.project_name
    }
  }
}
