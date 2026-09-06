# 🌐 RepairShop — Infraestrutura de Rede e Base (AWS Network)

[![Terraform](https://img.shields.io/badge/Terraform-1.8.5+-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS VPC](https://img.shields.io/badge/AWS-VPC%20%26%20Networking-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/vpc/)
[![AWS ECR](https://img.shields.io/badge/AWS-ECR%20Registry-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/ecr/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)

Repositório de **Infraestrutura como Código (IaC)** responsável pelo provisionamento da **camada fundamental de rede (VPC, Subnets, Gateways, Roteamento) e Container Registry (AWS ECR)** do ecossistema **RepairShop** (FIAP Tech Challenge — Fase 3).

---

## 🎯 Propósito e Escopo Arquitetural

A infraestrutura de rede estabelece a fundação de segurança e conectividade para todos os demais serviços do projeto (EKS, RDS, Lambda Auth e API Gateway). Seguindo os princípios do **AWS Well-Architected Framework (Pilar de Segurança e Confiabilidade)**:

- **Isolamento de Ambientes:** Segmentação completa de CIDR blocks por ambiente (`dev`: `10.0.0.0/16`, `hml`: `10.1.0.0/16`, `prd`: `10.2.0.0/16`).
- **Segregação em Múltiplas Zonas de Disponibilidade (Multi-AZ):**
  - **Sub-redes Públicas (2 AZs):** Destinadas exclusivamente ao Internet Gateway (IGW) e NAT Gateway com Elastic IP (EIP).
  - **Sub-redes Privadas (2 AZs):** Hospedagem segura de workloads (Cluster EKS, Banco RDS PostgreSQL e Lambda Functions) sem exposição pública de IP.
- **Registro Central de Imagens (AWS ECR):** Provisionamento do repositório privado `repairshop-${cluster_name}` com criptografia AES256 e políticas de ciclo de vida de imagens Docker.
- **State Backend Centralizado (S3):** Gerenciamento e garantia de existência do bucket `fiap-repairshop2` com versionamento e bloqueio de acesso público para armazenamento dos arquivos de estado (`.tfstate`).

---

## 🏗️ Topologia da Arquitetura de Rede

```mermaid
flowchart TB
    %% Definições de Estilo
    classDef internetStyle fill:#ECEFF1,stroke:#607D8B,stroke-width:2px,color:#263238
    classDef vpcStyle fill:#F5F7FA,stroke:#0277BD,stroke-width:2px,color:#01579B,stroke-dasharray: 4 4
    classDef azStyle fill:#FFFFFF,stroke:#B0BEC5,stroke-width:1px,stroke-dasharray: 2 2,color:#37474F
    classDef publicSubnetStyle fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px,color:#1B5E20
    classDef privateSubnetStyle fill:#FFF8E1,stroke:#F57F17,stroke-width:2px,color:#BF360C
    classDef gwStyle fill:#FF8F00,stroke:#E65100,stroke-width:2px,color:#FFFFFF
    classDef serviceStyle fill:#EDE7F6,stroke:#512DA8,stroke-width:2px,color:#311B92
    classDef workloadStyle fill:#E1F5FE,stroke:#0288D1,stroke-width:1px,color:#01579B
    classDef pubTagStyle fill:#FFFFFF,stroke:#4CAF50,stroke-width:1px,stroke-dasharray: 2 2,color:#2E7D32
    classDef privTagStyle fill:#FFFFFF,stroke:#FFA000,stroke-width:1px,stroke-dasharray: 2 2,color:#E65100

    subgraph InternetZone["🌐 Camada Externa / Internet"]
        IGW["🌐 Internet Gateway (IGW)\n0.0.0.0/0"]
    end
    class InternetZone internetStyle
    class IGW gwStyle

    subgraph AWS_VPC["🏢 AWS VPC — repairshop-vpc (CIDR: 10.x.0.0/16)"]
        subgraph AZ_1A["📍 Zona de Disponibilidade: us-east-1a"]
            subgraph Pub1["🟢 Subnet Pública 1 (10.x.0.0/24)"]
                TagPub1["🏷️ kubernetes.io/role/elb = 1"]:::pubTagStyle
                NAT["🔄 NAT Gateway (EIP Alocado)\nus-east-1a"]
                TagPub1 ~~~ NAT
            end

            subgraph Priv1["🔒 Subnet Privada 1 (10.x.2.0/24)"]
                TagPriv1["🏷️ kubernetes.io/role/internal-elb = 1"]:::privTagStyle
                EKS1["☸️ EKS NodeGroup\n(Worker Nodes)"]
                RDS1["🗄️ RDS PostgreSQL\n(Instância / Réplica)"]
                LAMBDA1["⚡ Lambda Auth\n(VPC Eni)"]
                TagPriv1 ~~~ EKS1
            end
        end

        subgraph AZ_1B["📍 Zona de Disponibilidade: us-east-1b"]
            subgraph Pub2["🟢 Subnet Pública 2 (10.x.1.0/24)"]
                TagPub2["🏷️ kubernetes.io/role/elb = 1"]:::pubTagStyle
                PubLB["⚖️ External Ingress / ALB"]
                TagPub2 ~~~ PubLB
            end

            subgraph Priv2["🔒 Subnet Privada 2 (10.x.3.0/24)"]
                TagPriv2["🏷️ kubernetes.io/role/internal-elb = 1"]:::privTagStyle
                EKS2["☸️ EKS NodeGroup\n(Worker Nodes)"]
                RDS2["🗄️ RDS PostgreSQL\n(Instância / Multi-AZ)"]
                LAMBDA2["⚡ Lambda Auth\n(VPC Eni)"]
                TagPriv2 ~~~ EKS2
            end
        end

        %% Tabelas de Roteamento
        subgraph RoutingTables["🧭 Tabelas de Roteamento (Route Tables)"]
            PublicRT["Public Route Table\n0.0.0.0/0 ➔ IGW"]
            PrivateRT["Private Route Table\n0.0.0.0/0 ➔ NAT Gateway"]
        end
    end
    class AWS_VPC vpcStyle
    class AZ_1A,AZ_1B azStyle
    class Pub1,Pub2 publicSubnetStyle
    class Priv1,Priv2 privateSubnetStyle
    class NAT gwStyle
    class EKS1,EKS2,RDS1,RDS2,LAMBDA1,LAMBDA2,PubLB workloadStyle
    class PublicRT,PrivateRT serviceStyle

    subgraph GlobalAWS["☁️ Serviços Centrais de Suporte (AWS Management)"]
        ECR["📦 AWS ECR (Container Registry)\nrepairshop-* (Scan on Push)"]
        S3Bucket["🪣 AWS S3 Remote State Bucket\nfiap-repairshop2 (SSE-AES256 / Versioned)"]
    end
    class GlobalAWS serviceStyle
    class ECR,S3Bucket serviceStyle

    %% Fluxos de Tráfego e Conectividade
    IGW <-->|"Inbound / Outbound"| Pub1 & Pub2
    Pub1 & Pub2 -.-> PublicRT
    NAT -->|"Egress Internet Traffic"| IGW
    
    Priv1 & Priv2 -.-> PrivateRT
    PrivateRT -->|"Outbound Seguro via NAT"| NAT

    Priv1 & Priv2 -->|"Download de Imagens"| ECR
    Priv1 & Priv2 -.->|"State Persistence / CI/CD"| S3Bucket
```

---

## 🗂️ Estrutura de Arquivos

```text
.
├── .github/workflows/
│   ├── ci-cd-network.yml     # Pipeline principal de CI/CD (Build, Test & Deploy)
│   └── destroy.yml           # Pipeline de destruição controlada com Safety Gate
├── infra/
│   ├── main.tf               # Definição de VPC, Subnets, IGW, NAT GW, ECR e Routes
│   ├── variables.tf          # Definição de tipos, defaults e descrições das variáveis
│   ├── outputs.tf            # Export de VPC ID, Subnet IDs, CIDRs e ECR URLs
│   ├── providers.tf          # Configuração do provedor AWS e versões
│   ├── backend.tf            # Configuração do backend remoto S3
│   └── environments/
│       ├── dev.tfvars        # Parâmetros do ambiente de Desenvolvimento
│       ├── hml.tfvars        # Parâmetros do ambiente de Homologação
│       └── prd.tfvars        # Parâmetros do ambiente de Produção
└── README.md
```

---

## 🚀 Pipeline de CI/CD (GitHub Actions)

A automação da infraestrutura de rede é orquestrada através do workflow [`.github/workflows/ci-cd-network.yml`](.github/workflows/ci-cd-network.yml).

### Desenho da Pipeline CI/CD

```mermaid
flowchart TD
    classDef triggerStyle fill:#E1F5FE,stroke:#0288D1,stroke-width:2px,color:#01579B
    classDef stepStyle fill:#F3E5F5,stroke:#7B1FA2,stroke-width:2px,color:#4A148C
    classDef gateStyle fill:#FFF9C4,stroke:#FBC02D,stroke-width:2px,color:#F57F17
    classDef deployStyle fill:#E8F5E9,stroke:#388E3C,stroke-width:2px,color:#1B5E20
    classDef reportStyle fill:#ECEFF1,stroke:#455A64,stroke-width:2px,color:#263238

    A["🎯 Disparo / Trigger\n• Push ou PR (main, homolog, dev)\n• Workflow Dispatch Manual"]:::triggerStyle
    A --> B["⚙️ Autenticação AWS\n(Configure AWS Credentials / IAM LabRole)"]:::stepStyle
    B --> C["📦 Garantia do Bucket S3\n(Verifica/Cria fiap-repairshop2 com SSE-AES256)"]:::stepStyle
    C --> D["🔍 Checagem de Formatação\n(terraform fmt -check na pasta infra/)"]:::stepStyle
    D --> E["⚡ Inicialização do Terraform\n(terraform init com backend S3 network/${ENV}.tfstate)"]:::stepStyle
    E --> F["📝 Geração do Plano\n(terraform plan -var-file=environments/${ENV}.tfvars)"]:::stepStyle
    F --> G{"🌿 Branch é 'main' com Push\nou Dispatch Manual?"}:::gateStyle
    
    G -- "✅ Sim (Deploy Aprovado)" --> H["🚀 Terraform Apply\n(terraform apply -auto-approve)"]:::deployStyle
    G -- "🛡️ Não (PR ou Homologação)" --> I["📋 Modo Dry-Run / Plan Only\n(Validação de Sintaxe e Mudanças)"]:::reportStyle
    
    H --> J["📊 GitHub Step Summary\n(Ambiente, Autor, Commit e Status do Job)"]:::reportStyle
    I --> J
```

### Detalhamento e Justificativa de Cada Passo da Pipeline

| Passo | Ação Executada | Justificativa Arquitetural |
| :--- | :--- | :--- |
| **1. Checkout repository** | Baixa o código-fonte no runner. | Garante que os arquivos Terraform da revisão exata estejam presentes para execução. |
| **2. Configure AWS Credentials** | Autentica via IAM Secrets/Session Token (`LabRole`). | Estabelece sessão segura com a AWS com permissões de menor privilégio. |
| **3. Ensure S3 Bucket State** | Verifica/Cria o bucket S3 `fiap-repairshop2` com versionamento e criptografia. | Garante a existência prévia do repositório central de estados sem falhas na primeira execução. |
| **4. Setup Terraform** | Instala a versão pinada do binário (Terraform `1.8.5`). | Previne divergências de comportamento e breaking changes entre versões da CLI. |
| **5. Terraform Format Check** | Executa `terraform fmt -check` na pasta `infra/`. | Assegura a conformidade com o padrão canônico de estilo de código HCL. |
| **6. Terraform Init** | Inicializa plugins e conecta o backend remoto S3 (`network/${ENV}.tfstate`). | Isola o arquivo de estado deste repositório dos demais componentes da arquitetura. |
| **7. Terraform Plan** | Gera o plano determinístico usando `environments/${ENV}.tfvars`. | Valida a sintaxe e visualiza o diff exato de recursos que serão criados ou alterados. |
| **8. Terraform Apply** | Aplica as alterações com `-auto-approve` (somente em `main` ou manual). | Garante deploy contínuo controlado, impedindo que PRs modifiquem o ambiente sem aprovação. |
| **9. Generate Summary** | Exporta tabela com ambiente, autor, commit e status no `$GITHUB_STEP_SUMMARY`. | Dá visibilidade imediata ao time de engenharia e auditoria sobre o deploy realizado. |

### 💡 Decisão de Arquitetura: Estratégia de Único Job (Single Job)

> **Decisão Arquitetural:** Toda a pipeline de validação e provisionamento foi consolidada em um **único JOB contínuo (`runs-on: ubuntu-latest`)**.
> 
> **Motivação Técnica:**
> 1. **Economia de Minutos e Quota da Conta:** Evita o custo temporal e financeiro de provisionar múltiplos runners virtuais no GitHub Actions, economizando a franquia limitada de minutos da conta.
> 2. **Eliminação de Overhead de Setup:** Reduz o tempo total de execução em mais de 60%, pois não é necessário repetir passos idênticos (download de Terraform, autenticação AWS e checkout de código) em múltiplos jobs sequenciais.
> 3. **Compartilhamento de Estado Local e Plugins:** Os provedores baixados no `terraform init` permanecem no workspace durante o `plan` e `apply`, eliminando upload/download de artefatos temporários entre jobs.

---

## 🔀 Governança de Branches e Ciclo de Promoção (Git Flow)

A governança do repositório segue isolamento estrito com aprovação controlada para promoção de ambientes:

```mermaid
flowchart LR
    classDef branchDev fill:#E3F2FD,stroke:#1E88E5,stroke-width:2px,color:#0D47A1
    classDef branchHml fill:#FFF3E0,stroke:#FB8C00,stroke-width:2px,color:#E65100
    classDef branchMain fill:#E8F5E9,stroke:#43A047,stroke-width:2px,color:#1B5E20
    classDef gateStyle fill:#FFEBEE,stroke:#E53935,stroke-width:2px,color:#B71C1C

    Dev["🌿 Feature / Fix / Chore\n(feat/*, fix/*, chore/*)"]:::branchDev
    PR_HML{"Pull Request\npara homolog"}:::gateStyle
    HML["🛡️ Branch homolog\n(Ambiente hml / Validação)"]:::branchHml
    PR_MAIN{"Pull Request\npara main"}:::gateStyle
    Main["🚀 Branch main\n(Deploy em Produção)"]:::branchMain

    Dev -->|"Abertura de PR"| PR_HML
    PR_HML -->|"Validação & Merge"| HML
    HML -->|"Abertura de PR de Promoção"| PR_MAIN
    PR_MAIN -->|"Aprovação Manual Obrigatória"| Main
```

> ⚠️ **Regra de Governança:** É expressamente proibido commit ou push direto na branch `main`. Toda alteração deve passar pelo pipeline de validação e aprovação formal.

---

## 💻 Execução e Deploy Local (Terraform CLI)

Caso seja necessário executar o provisionamento diretamente da máquina do operador:

```bash
# 1. Navegue até a pasta de infraestrutura
cd infra

# 2. Inicialize o backend remoto S3 para o ambiente desejado (ex: dev)
terraform init \
  -backend-config="bucket=fiap-repairshop2" \
  -backend-config="key=network/dev.tfstate" \
  -backend-config="region=us-east-1"

# 3. Valide a formatação e sintaxe dos arquivos
terraform fmt -check
terraform validate

# 4. Gere e visualize o plano de execução
terraform plan -var-file="environments/dev.tfvars"

# 5. Aplique o provisionamento na AWS
terraform apply -var-file="environments/dev.tfvars"
```

---

## 🔗 Links e Integrações no Ecossistema

- **Documentação de APIs (Swagger/OpenAPI):** Servida na aplicação principal em [http://localhost:8080/swagger-ui/index.html](http://localhost:8080/swagger-ui/index.html)
- **Coleção Postman:** Disponível em [`tech-challenge-repairshop-app/docs/postman/`](file:///c:/Users/Alexandre-AGAMIN/Projetos-%20FIAP/github-organizations-projects/tech-challenge-repairshop-app/docs/postman/)
- **Repositórios Dependentes:**
  - [`tech-challenge-repairshop-infra-eks`](https://github.com/fiap-postech-repairshop/tech-challenge-repairshop-infra-eks) (Consome as Sub-redes Privadas)
  - [`tech-challenge-repairshop-infra-db-rds`](https://github.com/fiap-postech-repairshop/tech-challenge-repairshop-infra-db-rds) (Consome as Sub-redes Privadas)
  - [`tech-challenge-repairshop-infra-apigateway`](https://github.com/fiap-postech-repairshop/tech-challenge-repairshop-infra-apigateway) (Consome as Sub-redes Públicas)
  - [`tech-challenge-repairshop-lambda-auth`](https://github.com/fiap-postech-repairshop/tech-challenge-repairshop-lambda-auth) (Consome as Sub-redes Privadas)
  - [`tech-challenge-repairshop-app`](https://github.com/fiap-postech-repairshop/tech-challenge-repairshop-app) (Aplicação Core EKS)
