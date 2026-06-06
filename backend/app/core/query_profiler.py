"""
SQLAlchemy Query Profiler — Development / Staging monitoring tool.

Counts the number of SQL queries executed per-request and logs a warning
when the count exceeds a configurable threshold.  The profiler is
**disabled by default in production** to avoid any performance overhead.

Usage (in app/main.py):
    from app.core.query_profiler import install_query_profiler
    install_query_profiler(app)

Environment variables:
    QUERY_PROFILER_ENABLED   – Set to "true" to enable (default: false).
    QUERY_PROFILER_THRESHOLD – Warn when query count exceeds this value
                               per request (default: 10).
"""
from __future__ import annotations

import logging
import time
from contextvars import ContextVar
from typing import Optional

from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Per-request context storage
# ---------------------------------------------------------------------------

# Total SQL statements executed in the current request context
_request_query_count: ContextVar[int] = ContextVar("_request_query_count", default=0)
# Wall-clock start of the current request (seconds)
_request_start_time: ContextVar[Optional[float]] = ContextVar(
    "_request_start_time", default=None
)


def _reset_counters() -> None:
    """Reset per-request counters at the start of each request."""
    _request_query_count.set(0)
    _request_start_time.set(time.perf_counter())


def _increment_query_count() -> int:
    """Increment the query counter and return the new value."""
    current = _request_query_count.get(0)
    new_value = current + 1
    _request_query_count.set(new_value)
    return new_value


def get_current_query_count() -> int:
    """Return the number of SQL queries executed so far in this request."""
    return _request_query_count.get(0)


def get_request_elapsed_ms() -> Optional[float]:
    """Return elapsed milliseconds since the start of the current request."""
    start = _request_start_time.get(None)
    if start is None:
        return None
    return (time.perf_counter() - start) * 1000


# ---------------------------------------------------------------------------
# SQLAlchemy engine instrumentation
# ---------------------------------------------------------------------------

def attach_query_counter(engine: AsyncEngine) -> None:
    """
    Register a SQLAlchemy ``before_cursor_execute`` event listener on the
    *sync* engine that backs the given async engine.

    This listener fires once per SQL statement and increments the
    per-request counter stored in a ``ContextVar``.
    """
    sync_engine = engine.sync_engine

    @event.listens_for(sync_engine, "before_cursor_execute")
    def _before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        _increment_query_count()


# ---------------------------------------------------------------------------
# FastAPI middleware integration
# ---------------------------------------------------------------------------

def install_query_profiler(
    app,
    *,
    engine: Optional[AsyncEngine] = None,
    threshold: int = 10,
    enabled: bool = False,
) -> None:
    """
    Attach the query profiler to a FastAPI application.

    Args:
        app:        The FastAPI application instance.
        engine:     The AsyncEngine to instrument.  If None, the profiler
                    still resets/reads counters but won't increment them
                    automatically — useful when the engine is created later.
        threshold:  Log a WARNING when a single request executes more than
                    this many SQL queries (default: 10).
        enabled:    Whether to activate the profiler (default: False).
                    Pass ``enabled=True`` explicitly for dev/staging.
    """
    if not enabled:
        logger.debug("Query profiler is disabled (set enabled=True to activate).")
        return

    if engine is not None:
        attach_query_counter(engine)
        logger.info("Query profiler attached to SQLAlchemy engine.")

    from starlette.middleware.base import BaseHTTPMiddleware
    from starlette.requests import Request
    from starlette.responses import Response

    class QueryProfilerMiddleware(BaseHTTPMiddleware):
        async def dispatch(self, request: Request, call_next) -> Response:
            _reset_counters()
            response = await call_next(request)
            query_count = get_current_query_count()
            elapsed_ms = get_request_elapsed_ms() or 0.0

            if query_count > threshold:
                logger.warning(
                    "🔴 N+1 SUSPECT | %s %s | queries=%d (threshold=%d) | %.1fms",
                    request.method,
                    request.url.path,
                    query_count,
                    threshold,
                    elapsed_ms,
                )
            else:
                logger.debug(
                    "✅ Query OK | %s %s | queries=%d | %.1fms",
                    request.method,
                    request.url.path,
                    query_count,
                    elapsed_ms,
                )

            # Expose query count in response header for debugging
            response.headers["X-Query-Count"] = str(query_count)
            response.headers["X-Response-Time-Ms"] = f"{elapsed_ms:.1f}"
            return response

    app.add_middleware(QueryProfilerMiddleware)
    logger.info(
        "Query profiler middleware installed (threshold=%d queries/request).",
        threshold,
    )
