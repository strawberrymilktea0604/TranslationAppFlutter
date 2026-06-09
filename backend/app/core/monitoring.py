import time
import logging
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi import FastAPI, Request, Response

logger = logging.getLogger(__name__)

REQUEST_COUNT = Counter(
    "translation_app_http_requests_total",
    "Total number of HTTP requests processed by the backend",
    ["method", "endpoint", "http_status"],
)
REQUEST_LATENCY = Histogram(
    "translation_app_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)
REQUEST_EXCEPTIONS = Counter(
    "translation_app_http_exceptions_total",
    "Total number of unhandled request exceptions",
    ["method", "endpoint", "exception_type"],
)


def setup_metrics(app: FastAPI) -> None:
    """Register Prometheus metrics route and HTTP middleware."""

    @app.middleware("http")
    async def prometheus_metrics_middleware(request: Request, call_next):
        start_time = time.time()
        endpoint = request.url.path
        method = request.method

        response = None
        try:
            response = await call_next(request)
            return response
        except Exception as exc:  # pragma: no cover
            REQUEST_EXCEPTIONS.labels(
                method=method,
                endpoint=endpoint,
                exception_type=exc.__class__.__name__,
            ).inc()
            raise
        finally:
            latency = time.time() - start_time
            status_code = getattr(response, "status_code", 500)
            REQUEST_COUNT.labels(
                method=method,
                endpoint=endpoint,
                http_status=str(status_code),
            ).inc()
            REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(latency)

    @app.get("/metrics", include_in_schema=False)
    async def metrics() -> Response:
        """Expose internal Prometheus metrics."""
        payload = generate_latest()
        return Response(content=payload, media_type=CONTENT_TYPE_LATEST)

    logger.info("Prometheus metrics endpoint registered at /metrics")
