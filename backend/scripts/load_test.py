import argparse
import asyncio
import time
from typing import Optional

import httpx


DEFAULT_TRANSLATE_PAYLOAD = {
    "text": "Hello world, this is a load testing payload.",
    "source_language": "en",
    "target_language": "vi",
}


async def worker(
    client: httpx.AsyncClient,
    url: str,
    payload: Optional[dict],
    requests_per_worker: int,
    results: list,
) -> None:
    for _ in range(requests_per_worker):
        start = time.monotonic()
        try:
            if payload is None:
                response = await client.get(url)
            else:
                response = await client.post(url, json=payload, timeout=30.0)
            elapsed = time.monotonic() - start
            results.append((elapsed, response.status_code))
        except Exception as exc:  # pragma: no cover
            elapsed = time.monotonic() - start
            results.append((elapsed, 0))
            print(f"Request failed: {exc}")


async def run_load_test(host: str, concurrency: int, total_requests: int, endpoint: str) -> None:
    url = f"{host.rstrip('/')}" + endpoint
    requests_per_worker = total_requests // concurrency
    extra = total_requests % concurrency
    results = []

    async with httpx.AsyncClient() as client:
        tasks = []
        for i in range(concurrency):
            count = requests_per_worker + (1 if i < extra else 0)
            tasks.append(worker(client, url, DEFAULT_TRANSLATE_PAYLOAD if endpoint.endswith("/text") else None, count, results))
        start = time.monotonic()
        await asyncio.gather(*tasks)
        duration = time.monotonic() - start

    success = sum(1 for _, status in results if 200 <= status < 300)
    failures = len(results) - success
    latencies = [lat for lat, status in results if status > 0]
    average_latency = sum(latencies) / len(latencies) if latencies else 0.0

    print("\nLoad test summary")
    print("-----------------")
    print(f"Host: {host}")
    print(f"Endpoint: {endpoint}")
    print(f"Total requests: {len(results)}")
    print(f"Success: {success}")
    print(f"Failures: {failures}")
    print(f"Total duration: {duration:.2f}s")
    print(f"Requests per second: {len(results) / duration:.2f}")
    print(f"Average latency: {average_latency * 1000:.1f} ms")
    if latencies:
        print(f"Min latency: {min(latencies) * 1000:.1f} ms")
        print(f"Max latency: {max(latencies) * 1000:.1f} ms")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simple load test script for TranslationApp backend")
    parser.add_argument("--host", default="http://localhost:8000", help="Backend host URL")
    parser.add_argument("--concurrency", type=int, default=10, help="Number of concurrent workers")
    parser.add_argument("--requests", type=int, default=50, help="Total number of requests")
    parser.add_argument(
        "--endpoint",
        default="/api/v1/translate/text",
        help="Endpoint path to load test (e.g. /health or /api/v1/translate/text)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    asyncio.run(run_load_test(args.host, args.concurrency, args.requests, args.endpoint))


if __name__ == "__main__":
    main()
