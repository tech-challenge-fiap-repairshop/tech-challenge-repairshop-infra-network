variable "aws_region" {
  description = "Região da AWS para provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (dev, hml, prd)"
  type        = string
  default     = "prd"
}

variable "cluster_name" {
  description = "Nome do Cluster EKS"
  type        = string
  default     = "repairshop-eks"
}

variable "vpc_cidr" {
  description = "Bloco CIDR para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

