# NYC Taxi Data Pipeline - Stack Tecnologias
## Desafio Técnico - Engenheiro de Dados Pleno

![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=for-the-badge&logo=databricks&logoColor=white)
![Delta Lake](https://img.shields.io/badge/Delta%20Lake-0084C7?style=for-the-badge&logo=delta&logoColor=white)
![Apache Spark](https://img.shields.io/badge/Apache%20Spark-E25A1C?style=for-the-badge&logo=apache-spark&logoColor=white)
![AWS S3](https://img.shields.io/badge/AWS%20S3-569A31?style=for-the-badge&logo=amazon-s3&logoColor=white)
![Unity Catalog](https://img.shields.io/badge/Unity%20Catalog-FF3621?style=for-the-badge&logo=databricks&logoColor=white)

## 📋 Visão Geral

Pipeline de dados completo para transformação e análise do dataset NYC Yellow Taxi Trip Data, implementando uma arquitetura moderna de lakehouse com Databricks, Delta Lake e Unity Catalog.

### 🎯 **Objetivos Alcançados**
- ✅ **Ingestão**: Dataset carregado manualmente para S3 (Bronze Layer)
- ✅ **Transformação**: Pipeline ETL com PySpark (Silver Layer)  
- ✅ **Agregação**: Métricas analíticas otimizadas (Gold Layer)
- ✅ **Warehouse**: Esquema estrela para consultas analíticas
- ✅ **Orquestração**: Databricks Workflows automatizado
- ✅ **Governança**: Unity Catalog com segurança e catalogação

### 📊 **Métricas do Pipeline**
- **46.4 milhões** de registros processados
- **98.17%** taxa de retenção de dados
- **541K** agregações horárias por localização
- **122 dias** de dados históricos (Jan 2015 - Mar 2016)
- **Performance sub-segundo** para consultas analíticas

## 🏗️ Arquitetura

### **Arquitetura Lakehouse Implementada**
```
📥 Kaggle Dataset (NYC Taxi)
    ↓
🥉 Bronze Layer (S3) - Dados Raw
    ↓ PySpark ETL
🥈 Silver Layer (S3) - Dados Limpos  
    ↓ Agregações
🥇 Gold Layer (S3) - Métricas Analíticas
    ↓ Schema Estrela
🏢 Warehouse (Delta) - Consultas Otimizadas
```

### **Stack Tecnológico**
- **Plataforma**: Databricks Workspace
- **Storage**: AWS S3 (us-west-2)
- **Processamento**: Apache Spark + PySpark
- **Formato**: Delta Lake
- **Governança**: Unity Catalog
- **Orquestração**: Databricks Workflows
- **Warehouse**: Databricks SQL Warehouse

## 🚀 Início Rápido

### **Pré-requisitos**
- Conta AWS com acesso a S3 e IAM
- Databricks Workspace (Premium/Enterprise)
- Dataset NYC Taxi baixado do Kaggle
- AWS CLI configurado

### **1. Configuração da Infraestrutura**
```bash
# Criar buckets S3
aws s3api create-bucket --bucket nyc-taxi-bronze-lucas --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2
aws s3api create-bucket --bucket nyc-taxi-silver-lucas --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2
aws s3api create-bucket --bucket nyc-taxi-gold-lucas --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2

# Upload manual do dataset NYC Taxi para camada Bronze
aws s3 cp yellow_tripdata_*.csv s3://nyc-taxi-bronze-lucas/raw/

# Configurar Unity Catalog (ver docs/setup.md)
```

### **2. Upload dos Dados (Camada Bronze)**
```bash
# Baixar dataset do Kaggle
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data

# Extrair arquivos CSV
unzip nyc-yellow-taxi-trip-data.zip

# Upload para S3 (camada Bronze)
aws s3 cp yellow_tripdata_2015-01.csv s3://nyc-taxi-bronze-lucas/raw/
aws s3 cp yellow_tripdata_2015-02.csv s3://nyc-taxi-bronze-lucas/raw/
# ... continuar para todos os arquivos necessários
```

### **3. Execução do Pipeline**
```python
# 1. Executar notebooks na ordem:
notebooks/02_bronze_to_silver_etl.py  
notebooks/03_silver_to_gold_aggregation.py
notebooks/04_sql_warehouse_setup.py

# 2. Ou usar Databricks Workflows (recomendado)
# Ver: workflows/nyc_taxi_pipeline.json
```

## 📁 Estrutura do Projeto

```
nyc-taxi-pipeline/
├── README.md
├── docs/
│   ├── architecture.md          # Arquitetura detalhada
│   ├── setup.md                # Guia de configuração
│   ├── data-modeling.md         # Modelagem de dados
│   └── performance.md           # Otimizações aplicadas
├── notebooks/
│   ├── 00_setup_and_configuration.py
│   ├── 02_bronze_to_silver_etl.py
│   ├── 03_silver_to_gold_aggregation.py
│   ├── 04_sql_warehouse_setup.py
│   ├── 05_databricks_workflows_orchestration.py
│   └── 06_data_visualization_dashboard.py
├── workflows/
│   └── nyc_taxi_pipeline.json   # Definição do workflow
├── sql/
│   ├── create_schemas.sql
│   ├── validation_queries.sql
│   └── analytics_views.sql
├── config/
│   └── unity_catalog_setup.sql
└── evidence/
    ├── screenshots/
    ├── performance_metrics.md
    └── data_quality_report.md
```

## 🔍 Resultados e Evidências

### **Qualidade dos Dados**
- **Taxa de Retenção**: 98.17% (46.4M de 47.2M registros)
- **Dados Válidos**: 99.9999% (apenas 10 registros com warnings)
- **Consistência Temporal**: 99.89% timestamps válidos
- **Coordenadas NYC**: 98.19% dentro dos limites geográficos

### **Performance do Pipeline**
- **Upload Manual Bronze**: Dataset carregado via AWS CLI
- **Transformação Silver**: ~15 minutos (46M registros)
- **Agregação Gold**: ~8 minutos (541K métricas)
- **Consultas Analíticas**: <1 segundo (média)

### **Métricas de Negócio**
- **Receita Total**: $722 milhões processados
- **Viagens Diárias**: 380K em média
- **Valor Médio**: $15.57 por viagem
- **Duração Média**: 14.5 minutos
- **Distância Média**: 3.33 km

### **📊 Visualizações e Dashboards**
- **Gráficos de Barras**: Receita por tipo de pagamento, distribuição horária
- **Métricas Executivas**: KPIs consolidados interativos
- **Análise Geográfica**: Top 10 regiões por volume de viagens
- **Tendências Temporais**: Padrões mensais e sazonalidade
- **Performance Analytics**: Dashboards no Databricks SQL

## 🔒 Segurança e Governança

### **Implementações de Segurança**
- ✅ **Criptografia**: S3 SSE-AES256 em repouso
- ✅ **IAM**: Princípio do menor privilégio
- ✅ **Unity Catalog**: Controle de acesso granular
- ✅ **External Locations**: Acesso controlado ao S3
- ✅ **Service Principals**: Autenticação automatizada

### **Catalogação de Dados**
- **Catálogo**: `nyc_taxi_catalog`
- **Schemas**: `bronze`, `silver`, `gold`, `warehouse`
- **Lineage**: Rastreamento automático Delta Lake
- **Metadados**: Documentação completa no Unity Catalog

## 📈 Consultas Analíticas

### **Exemplos de Queries**
```sql
-- Top 5 meses por receita (2015)
SELECT 
    month_name,
    monthly_trips,
    ROUND(monthly_revenue, 0) as revenue
FROM nyc_taxi_catalog.warehouse.vw_executive_dashboard
WHERE year = 2015
ORDER BY monthly_revenue DESC
LIMIT 5;

-- Análise por tipo de pagamento
SELECT 
    payment_type_desc,
    COUNT(*) as trips,
    ROUND(AVG(total_amount), 2) as avg_fare
FROM nyc_taxi_catalog.silver.nyc_taxi_trips
GROUP BY payment_type_desc
ORDER BY trips DESC;
```

## 🔧 Configuração e Deploy

### **Variáveis de Ambiente**
```bash
# AWS
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=us-west-2

# Databricks
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=your_token

# Kaggle
KAGGLE_USERNAME=your_username
KAGGLE_KEY=your_key
```

### **Configuração do Unity Catalog**
Ver documentação detalhada em [`docs/setup.md`](docs/setup.md)

## 🧪 Testes e Validação

### **Testes Implementados**
- ✅ **Integridade**: Contagem de registros por camada
- ✅ **Qualidade**: Validação de valores nulos e outliers
- ✅ **Performance**: Benchmarks de consultas
- ✅ **Consistência**: Verificação de agregações

### **Executar Testes**
```python
# Ver notebooks de validação
notebooks/05_data_validation.py
```

## 📊 Monitoramento

### **Métricas Monitoradas**
- Taxa de retenção de dados por camada
- Tempo de execução do pipeline
- Qualidade dos dados processados
- Performance das consultas analíticas

### **Alertas Configurados**
- Falhas no pipeline (email)
- Degradação de performance
- Problemas de qualidade de dados

## 👨‍💻 Autor

**Lucas Lovato**
- 📧 Email: lucaslovatotech@gmail.com
- 💼 LinkedIn: [lucas-lovato](https://www.linkedin.com/in/lucas-lovato-b22766239)
- 🐙 GitHub: [lucaslovato](https://github.com/lucaslovatorocha)

## 📄 Licença

Este projeto foi desenvolvido como parte do desafio técnico para Stack Tecnologias.

---

## 🏆 **Conclusão**

Pipeline completo de dados implementado com sucesso, demonstrando:
- **Arquitetura moderna** de lakehouse
- **Processamento escalável** com Spark
- **Governança robusta** com Unity Catalog  
- **Performance otimizada** para análises
- **Segurança enterprise** com AWS + Databricks

**Status**: ✅ **Produção Ready**
