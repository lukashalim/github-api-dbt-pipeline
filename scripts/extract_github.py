import os
import time
import json
import httpx
import duckdb
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

REPO_OWNER = "vercel"
REPO_NAME = "next.js"
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")

DB_PATH = "data/dev.duckdb"
os.makedirs("data", exist_ok=True)

HEADERS = {
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "dbt-duckdb-pipeline"
}
if GITHUB_TOKEN:
    HEADERS["Authorization"] = f"Bearer {GITHUB_TOKEN}"

@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    retry=retry_if_exception_type(httpx.HTTPStatusError)
)
def fetch_pull_requests_page(client: httpx.Client, page: int = 1, per_page: int = 100):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/pulls"
    params = {
        "state": "closed",
        "per_page": per_page,
        "page": page,
        "sort": "updated",
        "direction": "desc"
    }
    response = client.get(url, headers=HEADERS, params=params)
    if response.status_code in (429, 500, 502, 503, 504):
        response.raise_for_status()
    response.raise_for_status()
    return response.json()

def main():
    print(f"Fetching pull requests for {REPO_OWNER}/{REPO_NAME}...")
    all_prs = []
    max_pages = 3  # Fetch ~300 PRs for testing
    
    with httpx.Client(timeout=15.0, follow_redirects=True) as client:
        for page in range(1, max_pages + 1):
            print(f"Fetching page {page}...")
            prs = fetch_pull_requests_page(client, page=page)
            if not prs:
                break
            all_prs.extend(prs)
            time.sleep(0.5)

    print(f"Total PRs fetched: {len(all_prs)}")

    conn = duckdb.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS raw_github_prs (
            raw_payload JSON,
            loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.execute("TRUNCATE raw_github_prs;")

    print("Loading raw JSON into DuckDB...")
    for pr in all_prs:
        json_str = json.dumps(pr)
        conn.execute("INSERT INTO raw_github_prs (raw_payload) VALUES (?)", [json_str])

    conn.close()
    print("Ingestion complete. DuckDB connection closed.")

if __name__ == "__main__":
    main()
