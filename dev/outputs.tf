output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das sub-redes publicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das sub-redes privadas"
  value       = aws_subnet.private[*].id
}

output "sg_eks_otel_id" {
  description = "ID do Security Group para EKS e OTel Collector"
  value       = aws_security_group.eks_otel.id
}

output "sg_lambda_id" {
  description = "ID do Security Group para Lambda Auth"
  value       = aws_security_group.lambda.id
}

output "sg_rds_id" {
  description = "ID do Security Group para RDS"
  value       = aws_security_group.rds.id
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR"
  value       = aws_ecr_repository.repairshop.repository_url
}
