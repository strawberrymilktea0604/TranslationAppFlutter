import json
import logging
import os
import sys

from .config import settings


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        record_dict = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": settings.PROJECT_NAME,
            "environment": settings.ENVIRONMENT,
        }

        if record.exc_info:
            record_dict["exception"] = self.formatException(record.exc_info)

        if record.stack_info:
            record_dict["stack_info"] = self.formatStack(record.stack_info)

        if hasattr(record, "request_id"):
            record_dict["request_id"] = record.request_id

        return json.dumps(record_dict, ensure_ascii=False)


def configure_logging() -> None:
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLogFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers = []
    root_logger.addHandler(handler)
    root_logger.setLevel(log_level)

    handlers = [handler]
    for logger_name in ["uvicorn", "uvicorn.error", "uvicorn.access", "sqlalchemy"]:
        logger = logging.getLogger(logger_name)
        logger.handlers = handlers
        logger.setLevel(log_level)
        logger.propagate = True
