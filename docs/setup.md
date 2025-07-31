# Guia de Configuração - NYC Taxi Pipeline

## 📋 Pré-requisitos

### **Contas e Acessos Necessários**
- ✅ **Conta AWS** com billing ativo
- ✅ **Databricks Workspace** (Premium ou Enterprise)
- ✅ **Conta Kaggle** para download do dataset
- ✅ **Git** para versionamento do código

### **Permissões AWS Necessárias**
```json
{
  "required_permissions": [
    "s3:CreateBucket",
    "s3:GetObject", 
    "s3:PutObject",
    "s3:DeleteObject",
    "iam:CreateRole",
    "iam:AttachRolePolicy",
    "iam:PassRole"
  ]
}
```

### **Ferramentas Locais**
```bash
# AWS CLI
pip install awscli
aws configure

# Databricks CLI  
pip install databricks-cli
databricks configure --token

# Kaggle API
pip install kaggle
```

## 🚀 Configuração Passo a Passo

### **1. Configuração AWS**

#### **1.1. Criar Buckets S3**
```bash
# Região us-west-2 (importante para compatibilidade)
aws s3api create-bucket \
  --bucket nyc-taxi-bronze-lucas \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

aws s3api create-bucket \
  --bucket nyc-taxi-silver-lucas \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

aws s3api create-bucket \
  --bucket nyc-taxi-gold-lucas \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

aws s3api create-bucket \
  --bucket nyc-taxi-managed-lucaslovato \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
```

#### **1.2. Configurar Criptografia nos Buckets**
```bash
# Habilitar criptografia SSE-AES256
for bucket in nyc-taxi-bronze-lucas nyc-taxi-silver-lucas nyc-taxi-gold-lucas nyc-taxi-managed-lucaslovato; do
  aws s3api put-bucket-encryption \
    --bucket $bucket \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
done
```

#### **1.3. Habilitar Versionamento**
```bash
# Habilitar versionamento para recovery
for bucket in nyc-taxi-bronze-lucas nyc-taxi-silver-lucas nyc-taxi-gold-lucas; do
  aws s3api put-bucket-versioning \
    --bucket $bucket \
    --versioning-configuration Status=Enabled
done
```

#### **1.4. Criar IAM Role para Databricks**

**Trust Policy** (`trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "EXTERNAL-ID-PLACEHOLDER"
        }
      }
    }
  ]
}
```

**Permissions Policy** (`s3-permissions.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject", 
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:PutObjectAcl",
        "s3:GetObjectAcl",
        "s3:DeleteObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::nyc-taxi-bronze-lucas/*",
        "arn:aws:s3:::nyc-taxi-silver-lucas/*",
        "arn:aws:s3:::nyc-taxi-gold-lucas/*",
        "arn:aws:s3:::nyc-taxi-managed-lucaslovato/*"
      ]
    },
    {
      "Sid": "S3BucketAccess", 
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::nyc-taxi-bronze-lucas",
        "arn:aws:s3:::nyc-taxi-silver-lucas", 
        "arn:aws:s3:::nyc-taxi-gold-lucas",
        "arn:aws:s3:::nyc-taxi-managed-lucaslovato"
      ]
    }
  ]
}
```

**Criar Role:**
```bash
# Criar IAM role
aws iam create-role \
  --role-name databricks-unity-catalog-role \
  --assume-role-policy-document file://trust-policy.json

# Anexar política de permissões
aws iam put-role-policy \
  --role-name databricks-unity-catalog-role \
  --policy-name S3AccessPolicy \
  --policy-document file://s3-permissions.json
```

### **2. Configuração Databricks**

#### **2.1. Criar Unity Catalog Metastore**

1. **Acesse Databricks Account Console**:
   - URL: https://accounts.cloud.databricks.com/
   - Login como Account Admin

2. **Criar Metastore**:
   - Data → Metastores → Create Metastore
   - **Name**: `nyc-taxi-metastore`
   - **Region**: `Oregon (us-west-2)`
   - **Storage Location**: `s3://nyc-taxi-managed-lucaslovato/`
   - **IAM Role ARN**: `arn:aws:iam::ACCOUNT-ID:role/databricks-unity-catalog-role`

3. **Atualizar Trust Policy**:
   - Copie o External ID gerado pelo Databricks
   - Atualize a trust policy no AWS IAM
   - Substitua `EXTERNAL-ID-PLACEHOLDER` pelo ID real

#### **2.2. Configurar External Locations**

Execute no Databricks SQL Editor:
```sql
-- Criar Storage Credential (se não existir)
CREATE STORAGE CREDENTIAL IF NOT EXISTS nyc_taxi_credential
WITH AWS_ROLE
IAM_ROLE 'arn:aws:iam::ACCOUNT-ID:role/databricks-unity-catalog-role';

-- Bronze Layer
CREATE EXTERNAL LOCATION IF NOT EXISTS bronze_location 
URL 's3://nyc-taxi-bronze-lucas/'
WITH (CREDENTIAL `CREDENTIAL-ID`)
COMMENT 'Bronze layer - dados raw NYC Taxi';

-- Silver Layer  
CREATE EXTERNAL LOCATION IF NOT EXISTS silver_location
URL 's3://nyc-taxi-silver-lucas/'
WITH (CREDENTIAL `CREDENTIAL-ID`)
COMMENT 'Silver layer - dados limpos NYC Taxi';

-- Gold Layer
CREATE EXTERNAL LOCATION IF NOT EXISTS gold_location
URL 's3://nyc-taxi-gold-lucas/'
WITH (CREDENTIAL `CREDENTIAL-ID`)
COMMENT 'Gold layer - dados agregados NYC Taxi';
```

#### **2.3. Criar Catálogo e Schemas**
```sql
-- Criar catálogo principal
CREATE CATALOG IF NOT EXISTS nyc_taxi_catalog
COMMENT 'Catálogo principal para pipeline NYC Taxi';

-- Usar o catálogo
USE CATALOG nyc_taxi_catalog;

-- Criar schemas para cada camada
CREATE SCHEMA IF NOT EXISTS bronze
COMMENT 'Dados raw do Kaggle - NYC Taxi';

CREATE SCHEMA IF NOT EXISTS silver  
COMMENT 'Dados limpos e padronizados - NYC Taxi';

CREATE SCHEMA IF NOT EXISTS gold
COMMENT 'Dados agregados para análise - NYC Taxi';

CREATE SCHEMA IF NOT EXISTS warehouse
COMMENT 'Schema estrela para consultas analíticas - NYC Taxi';
```

### **3. Configuração do Dataset**

#### **3.1. Configurar Kaggle API**
```bash
# Criar arquivo de credenciais
mkdir -p ~/.kaggle
cat > ~/.kaggle/kaggle.json << EOF
{
  "username": "lucaslovatodarocha",
  "key": "904cbad2ff7bdeeb5c72ccbe5e9976b9"
}
EOF

chmod 600 ~/.kaggle/kaggle.json
```

#### **3.2. Download e Upload do Dataset**
```bash
# Download do Kaggle
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data

# Extrair arquivos
unzip nyc-yellow-taxi-trip-data.zip

# Upload para S3 Bronze
aws s3 cp yellow_tripdata_2015-01.csv s3://nyc-taxi-bronze-lucas/raw/
```

### **4. Deploy dos Notebooks**

#### **4.1. Estrutura de Notebooks**
```
notebooks/
├── 01_bronze_ingestion.py       # Ingestão de dados raw
├── 02_bronze_to_silver_etl.py   # Limpeza e transformação
├── 03_silver_to_gold_aggregation.py # Agregações analíticas
└── 04_sql_warehouse_setup.py    # Configuração warehouse
```

#### **4.2. Upload via Databricks CLI**
```bash
# Upload dos notebooks
databricks workspace import_dir notebooks/ /Workspace/Users/YOUR-EMAIL/nyc-taxi-pipeline/notebooks/
```

### **5. Configuração de Workflows**

#### **5.1. Criar Workflow via UI**
1. **Databricks Workspace** → **Workflows** → **Create Job**
2. **Nome**: `NYC_Taxi_Pipeline_Production`
3. **Adicionar Tasks**:
   - Task 1: `01_bronze_ingestion`
   - Task 2: `02_bronze_to_silver_etl` (depends on Task 1)
   - Task 3: `03_silver_to_gold_aggregation` (depends on Task 2)
   - Task 4: `04_sql_warehouse_setup` (depends on Task 3)

#### **5.2. Configurar Schedule**
- **Trigger Type**: Scheduled
- **Cron Expression**: `0 2 * * *` (diário às 2:00 AM)
- **Timezone**: America/Sao_Paulo

#### **5.3. Configurar Notificações**
- **On Success**: seu-email@exemplo.com
- **On Failure**: seu-email@exemplo.com

### **6. Configurações de Cluster**

#### **6.1. Cluster Configuration**
```json
{
  "cluster_name": "nyc-taxi-pipeline-cluster",
  "spark_version": "13.3.x-scala2.12",
  "node_type_id": "i3.xlarge",
  "num_workers": 2,
  "autoscale": {
    "min_workers": 2,
    "max_workers": 8
  },
  "spark_conf": {
    "spark.databricks.delta.preview.enabled": "true",
    "spark.sql.adaptive.enabled": "true",
    "spark.sql.adaptive.coalescePartitions.enabled": "true",
    "spark.databricks.delta.autoCompact.enabled": "true",
    "spark.databricks.delta.optimizeWrite.enabled": "true"
  },
  "aws_attributes": {
    "zone_id": "us-west-2a",
    "availability": "SPOT_WITH_FALLBACK",
    "first_on_demand": 1
  },
  "enable_elastic_disk": true
}
```

## 🧪 Validação da Configuração

### **Checklist de Validação**
```bash
# 1. Verificar buckets S3
aws s3 ls | grep nyc-taxi

# 2. Testar acesso ao Unity Catalog
databricks sql --query "SHOW CATALOGS"

# 3. Verificar external locations  
databricks sql --query "SHOW EXTERNAL LOCATIONS"

# 4. Testar notebook simples
databricks runs submit --json '{
  "run_name": "test-run",
  "new_cluster": {...},
  "notebook_task": {
    "notebook_path": "/path/to/test-notebook"
  }
}'
```

### **Troubleshooting Comum**

#### **Erro: External ID inválido**
```bash
# Solução: Atualizar trust policy com External ID correto
aws iam update-assume-role-policy \
  --role-name databricks-unity-catalog-role \
  --policy-document file://updated-trust-policy.json
```

#### **Erro: Permissões S3**
```bash
# Verificar políticas anexadas
aws iam list-attached-role-policies --role-name databricks-unity-catalog-role

# Testar acesso direto
aws s3 ls s3://nyc-taxi-bronze-lucas/ --profile databricks-role
```

#### **Erro: Unity Catalog não encontrado**
```sql
-- Verificar metastore assignment
SELECT * FROM system.information_schema.metastores;

-- Verificar current catalog
SELECT current_catalog();
```

## 📊 Monitoramento Inicial

### **Métricas para Acompanhar**
- Tempo de execução dos notebooks
- Volume de dados processados
- Taxa de erro por job
- Utilização de recursos do cluster

### **Logs Importantes**
- **Databricks Jobs**: Workflow execution logs
- **Spark UI**: Performance e resource utilization  
- **AWS CloudTrail**: S3 access logs
- **Unity Catalog**: Audit logs

## 🔐 Configurações de Segurança

### **Best Practices Implementadas**
- ✅ Princípio do menor privilégio (IAM)
- ✅ Criptografia em repouso (S3)
- ✅ Versionamento para recovery
- ✅ External locations controladas
- ✅ Service principals para automação

### **Próximos Passos de Segurança**
- [ ] VPC Endpoints para S3
- [ ] Private Link para Databricks
- [ ] Key rotation automática
- [ ] Audit log analysis

## 🚀 Deploy em Produção

### **Ambientes Recomendados**
1. **Development**: Workspace separado com dados sample
2. **Staging**: Replica da produção com dados reais
3. **Production**: Ambiente final com monitoring completo

### **CI/CD Pipeline**
```yaml
# GitHub Actions exemplo
name: Deploy NYC Taxi Pipeline
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy notebooks
        run: databricks workspace import_dir notebooks/ /production/
```

---

**⚠️ Importante**: Sempre teste em ambiente de desenvolvimento antes de aplicar em produção!