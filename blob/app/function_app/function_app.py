"""
Azure Function App – Elasticsearch Sync (stub).

Endpoints:
  POST /api/elastic/sync                   – Sync AI Search index → Elasticsearch (stubbed)
"""

import azure.functions as func
import json
import logging
import os

from azure.identity import DefaultAzureCredential

app = func.FunctionApp()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_skill_response(values: list[dict]) -> func.HttpResponse:
    """Wrap outputs in the AI Search custom skill response envelope."""
    return func.HttpResponse(
        json.dumps({"values": values}),
        mimetype="application/json",
        status_code=200,
    )


# ---------------------------------------------------------------------------
# Elasticsearch Sync (STUBBED – populate when Elasticsearch config is available)
# ---------------------------------------------------------------------------
@app.function_name("ElasticSync")
@app.route(route="elastic/sync", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def elastic_sync(req: func.HttpRequest) -> func.HttpResponse:
    """
    Sync documents from Azure AI Search index to an external Elasticsearch index.

    This endpoint is STUBBED for Phase 1. When Elasticsearch connection details
    become available, implement the actual sync logic here.

    Implements the AI Search custom skill interface:
      Input:  { "values": [{ "recordId": "...", "data": {...} }] }
      Output: { "values": [{ "recordId": "...", "data": {...}, "errors": [], "warnings": [] }] }
    """
    logging.info("ElasticSync invoked (STUB)")

    try:
        body = req.get_json()
    except ValueError:
        logging.warning("ElasticSync: Could not parse request body as JSON")
        return _make_skill_response([])

    input_values = body.get("values", [])
    logging.info("ElasticSync: Received %d record(s)", len(input_values))
    output_values = []

    elasticsearch_endpoint = os.environ.get("ELASTICSEARCH_ENDPOINT", "")
    elasticsearch_index = os.environ.get("ELASTICSEARCH_INDEX_NAME", "documents")

    for record in input_values:
        record_id = record.get("recordId", "")
        data = record.get("data", {})
        logging.info(
            "ElasticSync record=%s | title=%s | file_type=%s | source_url=%s | "
            "content_length=%d | key_phrases=%s | vector_dims=%d",
            record_id,
            data.get("title", ""),
            data.get("file_type", ""),
            data.get("source_url", ""),
            len(data.get("content", "") or ""),
            data.get("key_phrases", []),
            len(data.get("content_vector", []) or []),
        )

        if not elasticsearch_endpoint:
            output_values.append({
                "recordId": record_id,
                "data": {"status": "skipped"},
                "errors": [],
                "warnings": [{"message": "Elasticsearch endpoint not configured. Set ELASTICSEARCH_ENDPOINT when available."}],
            })
            continue

        # ------------------------------------------------------------------
        # TODO: Implement actual Elasticsearch sync when config is available
        # ------------------------------------------------------------------
        # from elasticsearch import Elasticsearch
        #
        # es_client = Elasticsearch(
        #     elasticsearch_endpoint,
        #     api_key=os.environ.get("ELASTICSEARCH_API_KEY"),
        # )
        #
        # # 1. Query AI Search for documents
        # from azure.search.documents import SearchClient
        # search_client = SearchClient(
        #     endpoint=os.environ["AI_SEARCH_ENDPOINT"],
        #     index_name=os.environ["AI_SEARCH_INDEX_NAME"],
        #     credential=DefaultAzureCredential(),
        # )
        # results = search_client.search(search_text="*", select=["*"])
        #
        # # 2. Transform and bulk upsert
        # actions = []
        # for doc in results:
        #     actions.append({
        #         "_index": elasticsearch_index,
        #         "_id": doc["id"],
        #         "_source": {
        #             "title": doc.get("title"),
        #             "content": doc.get("content"),
        #             "source_url": doc.get("source_url"),
        #             "file_type": doc.get("file_type"),
        #             "key_phrases": doc.get("key_phrases"),
        #             "entities": doc.get("entities"),
        #             "last_modified": doc.get("last_modified"),
        #         },
        #     })
        #
        # from elasticsearch.helpers import bulk
        # bulk(es_client, actions)

        output_values.append({
            "recordId": record_id,
            "data": {
                "status": "stub",
            },
            "errors": [],
            "warnings": [{"message": "Elasticsearch sync is stubbed. Implementation pending."}],
        })

    return _make_skill_response(output_values)
