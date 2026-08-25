provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "RepairShop"
      Component   = "Network"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
