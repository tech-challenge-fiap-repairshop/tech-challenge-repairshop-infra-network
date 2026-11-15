# 🌐🛡️ Repair Shop — Infra Network & Container Registry (`infra-network`)

[![CI/CD Pipeline](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-network/actions/workflows/ci-cd-network.yml/badge.svg)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-network/actions/workflows/ci-cd-network.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.8.5-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-VPC%20%7C%20NAT%20%7C%20ECR-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/)

Repositório de **Infraestrutura como Código (Terraform)** que provisiona a **camada de rede fundacional e o registro de imagens** da plataforma **Repair Shop (Tech Challenge FIAP — 15SOAT)** na AWS. Define a **VPC isolada por ambiente**, **sub-redes públicas e privadas** em múltiplas Zonas de Disponibilidade com tags nativas de Load Balancer para Kubernetes, **Internet Gateway**, **NAT Gateway** e **Amazon ECR**.

---

## 📋 Índice

- [Recursos Provisionados e Topologia de Rede](#recursos-provisionados-e-topologia-de-rede)
- [Arquitetura Atual — Motivação e Benefícios dos Componentes](#arquitetura-atual--motivação-e-benefícios-dos-componentes)
- [Por que DynamoDB em vez de Banco Relacional nos Serviços de OS e Pagamento?](#por-que-dynamodb-em-vez-de-banco-relacional-nos-serviços-de-os-e-pagamento)
- [Como Executar e Validar Localmente (Terraform)](#como-executar-e-validar-localmente-terraform)
- [Como Executar em Produção (Esteira CI/CD GitHub Actions)](#como-executar-em-produção-esteira-cicd-github-actions)
- [Documentação Técnica e Collection do Postman](#documentação-técnica-e-collection-do-postman)

---

## Recursos Provisionados e Topologia de Rede

Conforme definido em [`infra/main.tf`](infra/main.tf) e parametrizado por ambiente em `infra/environments/`:

| Recurso AWS | Configuração Técnica | Função na Plataforma |
| :--- | :--- | :--- |
| **`aws_vpc.main`** | DNS hostnames e DNS support habilitados; CIDR exclusivo por ambiente:<br>• `dev`: `10.0.0.0/16`<br>• `hml`: `10.1.0.0/16`<br>• `prd`: `10.2.0.0/16` | Isolamento completo de rede entre desenvolvimento, homologação e produção. |
| **`aws_subnet.public` (2 AZs)** | Sub-redes geradas com `cidrsubnet(var.vpc_cidr, 8, 0)` e `cidrsubnet(var.vpc_cidr, 8, 1)` com tag `kubernetes.io/role/elb = 1` | Hospedam o **NAT Gateway** e os Load Balancers de borda quando aplicável. |
| **`aws_subnet.private` (2 AZs)** | Sub-redes geradas com `cidrsubnet(var.vpc_cidr, 8, 2)` e `cidrsubnet(var.vpc_cidr, 8, 3)` com tag `kubernetes.io/role/internal-elb = 1` | Isolam os Worker Nodes do **EKS**, a instância **RDS**, o **ElastiCache Redis**, os **NLBs internos** dos microsserviços e a execução VPC do **Lambda Auth**. |
| **`aws_internet_gateway` & `aws_nat_gateway`** | 1 IGW + 1 NAT Gateway com EIP dedicado | Permite que pods e lambdas em sub-redes privadas acessem APIs externas (ex.: Mercado Pago, Pull ECR, Sonar/OTel) mantendo tráfego de entrada bloqueado da internet pública. |
| **`aws_ecr_repository.app`** | Repositório privado `repairshop-${var.cluster_name}` | Armazena imagens Docker construídas e escaneadas pelos microsserviços antes do deploy no EKS. |

> **Estado Remoto Compartilhado**: O `terraform.tfstate` é salvo no S3 em `network/${ENV}.tfstate`, servindo como *data source* (`terraform_remote_state`) para `infra-eks`, `infra-db-rds`, `infra-redis` e `lambda-auth`.

---

## Arquitetura Atual — Motivação e Benefícios dos Componentes

| Pilar / Tecnologia | Papel no Ecossistema | Motivação Técnica e Pontos Positivos |
| :--- | :--- | :--- |
| **RDS (PostgreSQL 16)** | Provisionado em sub-redes privadas desta VPC ([`infra-db-rds`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-rds)) | `publicly_accessible = false` e Security Group aceitando porta `5432` exclusivamente dos CIDRs das sub-redes privadas garante **Defesa em Profundidade (Zero Trust)** para os dados cadastrais do `register-service`. |
| **DynamoDB (NoSQL)** | Persistência *serverless* gerenciada para OS e Pagamentos ([`infra-db-dynamo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-dynamo)) | Consumido pelos pods em sub-rede privada via HTTPS com alta escalabilidade (`PAY_PER_REQUEST`), Single-Table Design e GSIs sem risco de exaustão de conexões TCP na rede privada. |
| **ElastiCache (Redis 7.0)** | Provisionado nas sub-redes privadas desta VPC ([`infra-redis`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-redis)) | Mantém o cache em memória acessível exclusivamente na rede interna (`6379` via Security Group privado) para sessões e tokens JWT do `register-service` sem expor o cluster externamente. |
| **Apps (EKS + Lambda Auth)** | Computação nas sub-redes privadas ([`infra-eks`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-eks), [`lambda-auth`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-lambda-auth)) | Separa workloads contínuos em **EKS 1.31** (com HPA e NLBs internos marcados com `internal-elb=1`) de autenticação elástica *serverless* em Lambda, todos isolados em sub-redes privadas. |
| **Amazon SQS (Mensageria + DLQ)** | Barramento assíncrono com 5 filas + 5 DLQs ([`infra-sqs`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-sqs)) | Garante comunicação resiliente e desacoplada entre contextos (Saga Coreografada) através de polling/enfileiramento seguro sem abrir portas diretas entre microsserviços na rede privada. |
| **API Gateway (HTTP API v2)** | Borda pública controlada ([`infra-apigateway`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-apigateway)) | Único ponto exposto publicamente, roteando `POST /auth/login` ao `lambda-auth` e demais chamadas aos NLBs descobertos dinamicamente nas sub-redes do EKS, com CORS configurado para headers `traceparent` e `tracestate`. |
| **Observabilidade (Grafana)** | Telemetria centralizada no cluster EKS | OpenTelemetry Collector recebe métricas (Prometheus), logs (Loki) e traces (Jaeger) dos microsserviços e Lambda Auth dentro da VPC, consolidando tudo nos 11 dashboards Grafana. |

---

## Por que DynamoDB em vez de Banco Relacional nos Serviços de OS e Pagamento?

Mesmo operando dentro de sub-redes privadas bem estruturadas nesta VPC, **RDS** e **DynamoDB** têm papéis complementares bem definidos:

1. **Prevenção de gargalo de IPs, ENIs e conexões JDBC**: Em um cluster Kubernetes com múltiplos pods escalando via HPA nas sub-redes privadas, cada instância de aplicação abrindo pool JDBC contra um RDS concentra carga de rede e memória em um único endpoint relacional. O DynamoDB opera via API HTTPS gerenciada fora do gargalo de conexões TCP de instância única.
2. **Agregados polimórficos sem `JOIN`s pesados**: Ordens de Serviço (`ORDER#<id>`) e Pagamentos (`BILLING#<id>`) agrupam histórico, tarefas extras e faturas em **Single-Table Design** com transações atômicas (`TransactWriteItems`) e evolução livre de atributos sem *locks* DDL.
3. **Escalabilidade sob demanda e GSIs otimizados**: Índices secundários globais (`pending-dispatch-index` e `dispatch-notification-index`) permitem que processos assíncronos encontrem pendências rapidamente sem `Scan` completo e pagando apenas pelo consumo (`PAY_PER_REQUEST`).

---

## Como Executar e Validar Localmente (Terraform)

> **Pré-requisitos**: **Terraform `1.8.5`** (ou compatível `~> 1.x`), **AWS CLI v2** autenticado na conta alvo e nome do bucket S3 de state remoto.

```bash
cd infra

# Inicializar apontando para o backend S3 de estado remoto (ex.: ambiente dev)
terraform init \
  -backend-config="bucket=SEU_BUCKET_TERRAFORM_STATE" \
  -backend-config="key=network/dev.tfstate" \
  -backend-config="region=us-east-1"

# Validar formatação e sintaxe HCL
terraform fmt -check -recursive
terraform validate

# Simular o plano de infraestrutura usando o arquivo tfvars do ambiente desejado
terraform plan -var-file="environments/dev.tfvars"
```

Para testar apenas sintaxe e formatação localmente **sem inicializar o backend remoto S3**:
```bash
cd infra
terraform init -backend=false
terraform validate
```

---

## Como Executar em Produção (Esteira CI/CD GitHub Actions)

O provisionamento e destruição controlada são executados via [`.github/workflows/ci-cd-network.yml`](.github/workflows/ci-cd-network.yml) e [`.github/workflows/destroy.yml`](.github/workflows/destroy.yml).

### Regras de Ambiente por Branch (`ci-cd-network.yml`)
- `develop` -> ambiente **`dev`** (`environments/dev.tfvars`)
- `homolog` -> ambiente **`hml`** (`environments/hml.tfvars`)
- `main` -> ambiente **`prd`** (`environments/prd.tfvars`)
- `pull_request` -> executa `terraform plan` para revisão antes do merge.

### Fluxo da Pipeline
1. `terraform fmt -check` -> garante padronização do código HCL.
2. `terraform init` com chave S3 `network/${ENV}.tfstate` e `AWS_TERRAFORM_STATE_BUCKET`.
3. `terraform validate` -> valida consistência dos blocos Terraform.
4. `terraform plan -var-file="environments/${ENV}.tfvars"` -> calcula alterações.
5. `terraform apply -auto-approve` -> executado em push direto nas branches `develop`, `homolog` e `main`.

### Posição na Ordem Oficial de Provisionamento
Este repositório deve ser **o 1º a ser provisionado** antes de `infra-db-rds`, `infra-redis`, `infra-eks` e `lambda-auth`, pois fornece a VPC, sub-redes e state remoto consumidos pelos demais módulos.

---

## Documentação Técnica e Collection do Postman

- **Arquivos Terraform deste Repositório**: [`infra/main.tf`](infra/main.tf) | [`infra/environments/dev.tfvars`](infra/environments/dev.tfvars) | [`infra/environments/hml.tfvars`](infra/environments/hml.tfvars) | [`infra/environments/prd.tfvars`](infra/environments/prd.tfvars)
- **ADRs, RFCs e Diagrama de Infraestrutura Cloud**:
  - [ADRs (`ADR-001` a `ADR-013`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/ADRs/README.md)
  - [RFCs (`RFC-001` a `RFC-014`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/RFCs/README.md)
  - [`Diagrama de Infraestrutura Cloud`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/delivery/infrastructure/repairshop-diagrama-infra-cloud.svg)
- **Postman Collections & Environments (Organização)**:
  - Collection Principal: [`Repair Shop (Tech Challenge FIAP)`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Repair%20Shop%20%28Tech%20Challenge%20FIAP%29.postman_collection.json)
  - Collection Completa: [`Tech Challenge FIAP - Completo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Tech_Challenge_Fiap_-_Completo.postman_collection.json)
  - Environment Local: [`Local.postman_environment.json`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Local.postman_environment.json)
  - Guia do Postman: [`docs/postman/README.md`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/README.md)
- **Dashboards Grafana (11 JSONs)**: [`dashboards/`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/tree/main/local/observability/grafana/dashboards)
