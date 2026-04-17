# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "my-prototype"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group (overrides auto-generated name)"
  type        = string
}

# -----------------------------------------------------------------------------
# AI Search
# -----------------------------------------------------------------------------
variable "ai_search_sku" {
  description = "SKU for Azure AI Search (free, basic, standard, standard2, standard3)"
  type        = string
  default     = "standard"
}

variable "search_index_name" {
  description = "Name of the primary search index"
  type        = string
  default     = "documents-index"
}

# -----------------------------------------------------------------------------
# SharePoint
# -----------------------------------------------------------------------------
variable "sharepoint_site_url" {
  description = "SharePoint site URL for content ingestion"
  type        = string
}

# -----------------------------------------------------------------------------
# Elasticsearch (Phase 1 - Stub)
# -----------------------------------------------------------------------------
variable "elasticsearch_endpoint" {
  description = "Elasticsearch endpoint URL (leave empty to stub)"
  type        = string
  default     = ""
}

variable "elasticsearch_api_key" {
  description = "Elasticsearch API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "elasticsearch_index_name" {
  description = "Elasticsearch index name"
  type        = string
  default     = "documents"
}

# -----------------------------------------------------------------------------
# AI Foundry / Embedding Model
# -----------------------------------------------------------------------------
variable "embedding_model_name" {
  description = "Name of the embedding model to deploy"
  type        = string
  default     = "text-embedding-3-small"
}

variable "embedding_model_version" {
  description = "Version of the embedding model"
  type        = string
  default     = "1"
}

variable "embedding_model_capacity" {
  description = "TPM capacity (in thousands) for the embedding model deployment"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# AI Foundry Project
# -----------------------------------------------------------------------------
variable "foundry_project_name" {
  description = "Name for the AI Foundry project (defaults to ai-project-{project_name}-{environment})"
  type        = string
  default     = ""
}

variable "enable_hosted_agents" {
  description = "Enable hosted agent capability host on the Foundry account"
  type        = bool
  default     = false
}
