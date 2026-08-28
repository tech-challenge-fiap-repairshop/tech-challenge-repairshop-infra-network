output "vpc_id" {
  description = "ID da VPC criada"
  value       = try(aws_vpc.main.id, "")
}

output "public_subnet_ids" {
  description = "IDs das sub-redes publicas"
  value       = try(aws_subnet.public[*].id, [])
}

output "private_subnet_ids" {
  description = "IDs das sub-redes privadas"
  value       = try(aws_subnet.private[*].id, [])
}

output "vpc_cidr_block" {
  description = "Bloco CIDR principal da VPC"
  value       = try(aws_vpc.main.cidr_block, "")
}

output "private_subnet_cidr_blocks" {
  description = "Blocos CIDR das sub-redes privadas"
  value       = try(aws_subnet.private[*].cidr_block, [])
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR"
  value       = try(aws_ecr_repository.repairshop.repository_url, "")
}
