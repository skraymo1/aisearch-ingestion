# AI Search Ingestion

Terraform-managed pipelines for ingesting documents into [Azure AI Search](https://learn.microsoft.com/azure/search/) from multiple data sources. Each pipeline includes infrastructure-as-code, AI Search resource definitions (index, skillset, data sources, indexers), and an Azure Function App for downstream Elasticsearch sync.

## Data Source Pipelines

| Pipeline | Directory | Description |
|---|---|---|
| **Blob Storage** | `blob/` | Indexes documents from an Azure Blob Storage container |
| **SharePoint Online** | `sharepoint/` | Indexes documents from a SharePoint site with Entra ID app credentials |

Both pipelines share the same enrichment flow:

1. **Text chunking** – `ContentUnderstandingSkill` (SharePoint) or `SplitSkill` (Blob) splits documents into overlapping 2 000-character pages
2. **Vector embeddings** – `AzureOpenAIEmbeddingSkill` generates embeddings via `text-embedding-3-small`
3. **Key-phrase extraction** – `KeyPhraseExtractionSkill` for faceting and relevancy
4. **Entity recognition** – `EntityRecognitionSkill` extracts people, orgs, locations, etc.
5. **Elasticsearch sync** – `WebApiSkill` calls an Azure Function to push enriched chunks to Elasticsearch *(stubbed for Phase 1)*

## Repository Structure

```
blob/
  app/
    function_app/     # Azure Function – Elasticsearch sync (Python)
    search/           # AI Search JSON definitions & deploy script
  infra/              # Terraform – Azure resources (search, storage, AI Foundry, etc.)

sharepoint/
  app/
    function_app/     # Azure Function – Elasticsearch sync (Python)
    search/           # AI Search JSON definitions & deploy script (includes SharePoint data source)
  infra/              # Terraform – Azure resources (includes Entra ID app registration for SharePoint)
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az login`)
- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) (for local testing)
- Python 3.10+
- An Azure subscription with permissions to create resources

## Getting Started

### 1. Provision Infrastructure

```bash
cd blob/infra   # or sharepoint/infra

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your subscription ID, resource group, etc.

terraform init
terraform plan
terraform apply
```

Key resources created:

- Azure AI Search (standard SKU with semantic search)
- Azure Blob Storage
- Azure AI Services (for embeddings & cognitive skills)
- Azure AI Foundry project
- Azure Key Vault
- Azure Function App (Linux, Python)
- Managed identities with least-privilege RBAC
- *(SharePoint only)* Entra ID app registration with `Files.Read.All` + `Sites.Read.All`

### 2. Deploy Search Resources

```bash
cd blob/app/search   # or sharepoint/app/search

pip install requests azure-identity

python deploy_search.py \
  --search-endpoint https://srch-<project>-<env>.search.windows.net \
  --function-app-url https://func-<project>-<env>.azurewebsites.net \
  --ai-services-endpoint https://ais-<project>-<env>.cognitiveservices.azure.com \
  --subscription-id <sub-id> \
  --resource-group <rg-name> \
  --storage-account-name <storage-name>
```

Deploy specific resource types with `--only`:

```bash
python deploy_search.py --search-endpoint ... --only index skillset
```

### 3. Run an Indexer

```bash
# Blob pipeline
python deploy_search.py \
  --search-endpoint https://srch-<project>-<env>.search.windows.net \
  --run-indexer

# SharePoint pipeline
python deploy_search.py \
  --search-endpoint https://srch-<project>-<env>.search.windows.net \
  --run-indexer sharepoint
```

### 4. Test Queries

```bash
# Blob pipeline
python deploy_search.py \
  --search-endpoint https://srch-<project>-<env>.search.windows.net \
  --test-query "budget report"

# SharePoint pipeline
python deploy_search.py \
  --search-endpoint https://srch-<project>-<env>.search.windows.net \
  --test-query "budget report"
```

## Configuration

### Terraform Variables

| Variable | Default | Description |
|---|---|---|
| `subscription_id` | — | Azure subscription ID |
| `project_name` | `my-prototype` | Used in resource naming |
| `environment` | `dev` | Environment label (`dev`, `staging`, `prod`) |
| `location` | `eastus2` | Azure region |
| `ai_search_sku` | `standard` | AI Search SKU tier |
| `embedding_model_name` | `text-embedding-3-small` | Embedding model deployed via AI Foundry |
| `elasticsearch_endpoint` | `""` | Elasticsearch URL *(leave empty to stub)* |
| `sharepoint_site_url` | — | *(SharePoint only)* Site URL to index |

See `terraform.tfvars.example` in each `infra/` directory for the full list.

## Elasticsearch Integration

The Elasticsearch sync is **stubbed** for Phase 1. The Azure Function logs incoming enriched documents but does not push to Elasticsearch. To enable:

1. Set the `ELASTICSEARCH_ENDPOINT` and `ELASTICSEARCH_API_KEY` environment variables on the Function App
2. Uncomment the `elasticsearch` dependency in `requirements.txt`
3. Implement the sync logic in `function_app.py`

## License

[MIT](LICENSE)
