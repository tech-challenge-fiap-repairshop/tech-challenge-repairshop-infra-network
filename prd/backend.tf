terraform {
  backend "s3" {
    bucket  = "fiap-repairshop2"
    key     = "network/prd.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
