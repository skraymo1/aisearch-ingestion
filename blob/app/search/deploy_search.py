"""
Deploy Azure AI Search resources: index, skillset, data source, and indexer.

Usage:
  python deploy_search.py \
    --search-endpoint https://srch-my-prototype-dev.search.windows.net \
    --function-app-url https://func-my-prototype-dev.azurewebsites.net \
    --ai-services-endpoint https://ais-my-prototype-dev.cognitiveservices.azure.com \
    --subscription-id <sub-id> \
    --resource-group <rg-name> \
    --storage-account-name <storage-name>

  # Manually run the blob indexer:
  python deploy_search.py \
    --search-endpoint https://srch-my-prototype-dev.search.windows.net \
    --run-indexer

  # Test query:
  python deploy_search.py \
    --search-endpoint https://srch-my-prototype-dev.search.windows.net \
    --test-query "budget report"

Authentication: Uses AzureCliCredential (az login).
"""

import argparse
import json
import logging
import os
from pathlib import Path

import requests
from azure.identity import AzureCliCredential

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

SEARCH_API_VERSION = "2025-11-01-Preview"
SCRIPT_DIR = Path(__file__).parent


def get_access_token() -> str:
    credential = AzureCliCredential()
    token = credential.get_token("https://search.azure.com/.default")
    return token.token


def load_json(filename: str) -> dict:
    filepath = SCRIPT_DIR / filename
    with open(filepath, "r") as f:
        return json.load(f)


def replace_placeholders(obj: dict, replacements: dict) -> dict:
    """Recursively replace {{PLACEHOLDER}} strings in a dict."""
    text = json.dumps(obj)
    for key, value in replacements.items():
        text = text.replace(f"{{{{{key}}}}}", value or "")
    return json.loads(text)


def put_resource(endpoint: str, resource_type: str, name: str, body: dict, token: str):
    url = f"{endpoint}/{resource_type}/{name}?api-version={SEARCH_API_VERSION}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    # Remove _comment fields before sending
    body.pop("_comment", None)

    response = requests.put(url, headers=headers, json=body)
    if response.status_code in (200, 201, 204):
        logger.info(f"✓ {resource_type}/{name} deployed successfully")
    else:
        logger.error(f"✗ {resource_type}/{name} failed ({response.status_code}): {response.text}")
        response.raise_for_status()


def run_indexer(endpoint: str, indexer_name: str, token: str):
    """Trigger a manual indexer run via POST."""
    url = f"{endpoint}/indexers/{indexer_name}/run?api-version={SEARCH_API_VERSION}"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(url, headers=headers)
    if response.status_code == 202:
        logger.info(f"✓ Indexer '{indexer_name}' run triggered")
    else:
        logger.error(f"✗ Failed to run indexer ({response.status_code}): {response.text}")
        response.raise_for_status()


def test_query(endpoint: str, index_name: str, token: str, search_text: str):
    """Run a test query against the index."""
    url = f"{endpoint}/indexes/{index_name}/docs/search?api-version={SEARCH_API_VERSION}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    body = {
        "search": search_text,
        "count": True,
        "top": 5,
        "select": "id,title,file_name,source_url,file_type,key_phrases",
    }
    response = requests.post(url, headers=headers, json=body)
    if response.status_code != 200:
        logger.error(f"✗ Query failed ({response.status_code}): {response.text}")
        response.raise_for_status()

    result = response.json()
    count = result.get("@odata.count", "?")
    docs = result.get("value", [])
    logger.info(f"✓ Query returned {count} total results (showing top {len(docs)})")
    for doc in docs:
        logger.info(
            f"  • {doc.get('file_name', doc.get('id','?'))}"
            f"  type={doc.get('file_type', '?')}"
        )


def main():
    parser = argparse.ArgumentParser(description="Deploy Azure AI Search resources")
    parser.add_argument("--search-endpoint", required=True, help="AI Search endpoint URL")
    parser.add_argument("--function-app-url", default="", help="Azure Function App URL")
    parser.add_argument("--function-host-key", default=os.getenv("FUNCTION_HOST_KEY", ""),
                        help="Function App host key for WebApiSkill auth")
    parser.add_argument("--ai-services-endpoint", default="", help="AI Services endpoint URL")

    # Blob storage config
    parser.add_argument("--subscription-id", default=os.getenv("AZURE_SUBSCRIPTION_ID", ""))
    parser.add_argument("--resource-group", default=os.getenv("RESOURCE_GROUP", ""))
    parser.add_argument("--storage-account-name", default=os.getenv("STORAGE_ACCOUNT_NAME", ""))

    # Optional: deploy only specific resources
    parser.add_argument("--only", nargs="*", choices=["index", "skillset", "datasources", "indexers"],
                        help="Deploy only specified resource types")

    # Manual indexer run
    parser.add_argument("--run-indexer", action="store_true",
                        help="Trigger a manual blob indexer run")

    # Test query
    parser.add_argument("--test-query", nargs="?", const="*", default=None,
                        help="Run a test query (default: '*')")
    parser.add_argument("--index-name", default="documents-index",
                        help="Target index name (default: documents-index)")

    args = parser.parse_args()

    # --- Test-query mode ---
    if args.test_query is not None:
        token = get_access_token()
        test_query(args.search_endpoint, args.index_name, token, args.test_query)
        return

    # --- Run-indexer mode ---
    if args.run_indexer:
        token = get_access_token()
        logger.info("Triggering manual run for 'indexer-blob'...")
        run_indexer(args.search_endpoint, "indexer-blob", token)
        logger.info("Indexer triggered. Check status in Azure Portal or via REST API.")
        return

    # Validate required args for deploy mode
    if not args.function_app_url or not args.ai_services_endpoint:
        parser.error("--function-app-url and --ai-services-endpoint are required for deployment")

    replacements = {
        "FUNCTION_APP_URL": args.function_app_url,
        "FUNCTION_HOST_KEY": args.function_host_key,
        "AI_SERVICES_ENDPOINT": args.ai_services_endpoint,
        "SUBSCRIPTION_ID": args.subscription_id,
        "RESOURCE_GROUP": args.resource_group,
        "STORAGE_ACCOUNT_NAME": args.storage_account_name,
    }

    deploy_all = args.only is None
    token = get_access_token()

    # 1. Deploy index
    if deploy_all or "index" in args.only:
        logger.info("Deploying index...")
        index_def = load_json("index.json")
        index_def = replace_placeholders(index_def, replacements)
        put_resource(args.search_endpoint, "indexes", index_def["name"], index_def, token)

    # 2. Deploy skillset
    if deploy_all or "skillset" in args.only:
        logger.info("Deploying skillset...")
        skillset_def = load_json("skillset.json")
        skillset_def = replace_placeholders(skillset_def, replacements)
        put_resource(args.search_endpoint, "skillsets", skillset_def["name"], skillset_def, token)

    # 3. Deploy blob data source
    if deploy_all or "datasources" in args.only:
        if args.storage_account_name:
            logger.info("Deploying Blob data source...")
            blob_ds = load_json("datasource_blob.json")
            blob_ds = replace_placeholders(blob_ds, replacements)
            put_resource(args.search_endpoint, "datasources", blob_ds["name"], blob_ds, token)
        else:
            logger.warning("Skipping Blob data source (no storage account configured)")

    # 4. Deploy blob indexer (manual schedule)
    if deploy_all or "indexers" in args.only:
        if args.storage_account_name:
            logger.info("Deploying Blob indexer (manual schedule)...")
            blob_idx = load_json("indexer_blob.json")
            blob_idx = replace_placeholders(blob_idx, replacements)
            put_resource(args.search_endpoint, "indexers", blob_idx["name"], blob_idx, token)

    logger.info("Deployment complete.")


if __name__ == "__main__":
    main()
