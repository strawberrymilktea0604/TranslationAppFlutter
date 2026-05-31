"""
Real-time Session Logging Service

Provides comprehensive structured logging for WebSocket conversations,
including STT, translation, and multi-speaker sessions with performance
metrics and error tracking.

Features:
- Real-time event logging (session_start, audio_chunk, utterance, translation, etc.)
- Performance metrics (latency, throughput, accuracy)
- Error and exception tracking
- Audit trail for admin activities
- JSON structured logging for centralized aggregation
- Integration with FluentD for log forwarding
"""

import json
import logging
import time
import uuid
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from enum import Enum

logger = logging.getLogger(__name__)


class SessionEventType(str, Enum):
    """Types of events that occur in real-time sessions"""
    SESSION_START = "session_start"
    SESSION_END = "session_end"
    SESSION_ERROR = "session_error"
    AUDIO_CHUNK_RECEIVED = "audio_chunk_received"
    UTTERANCE_STARTED = "utterance_started"
    UTTERANCE_ENDED = "utterance_ended"
    WAV_CONVERSION_COMPLETED = "wav_conversion_completed"
    STT_PROCESSING = "stt_processing"
    STT_COMPLETED = "stt_completed"
    STT_ERROR = "stt_error"
    TRANSLATION_PROCESSING = "translation_processing"
    TRANSLATION_COMPLETED = "translation_completed"
    TRANSLATION_ERROR = "translation_error"
    MESSAGE_PERSISTED = "message_persisted"
    FINAL_TRANSLATION_SENT = "final_translation_sent"
    SPEAKER_CHANGED = "speaker_changed"
    KEEPALIVE = "keepalive"
    CONNECTION_CLOSED = "connection_closed"
    RATE_LIMIT_EXCEEDED = "rate_limit_exceeded"


class SessionLogLevel(str, Enum):
    """Logging levels for session events"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class RealtimeSessionLogger:
    """
    Structured logger for real-time WebSocket sessions.
    
    All events are logged as JSON with standardized fields for
    easy parsing and aggregation in ELK/FluentD stacks.
    """
    
    def __init__(self, session_id: Optional[str] = None):
        self.session_id = session_id or str(uuid.uuid4())
        self.start_time = time.time()
        self.event_count = 0
        self.bytes_received = 0
        self.bytes_transmitted = 0
        self._event_logger = logging.getLogger("realtime_session")
        
    def log_event(
        self,
        event_type: SessionEventType,
        level: SessionLogLevel = SessionLogLevel.INFO,
        user_id: Optional[int] = None,
        details: Optional[Dict[str, Any]] = None,
        latency_ms: Optional[float] = None,
        error: Optional[str] = None,
        **kwargs
    ) -> None:
        """
        Log a structured event for real-time session.
        
        Args:
            event_type: Type of event that occurred
            level: Logging level (INFO, WARNING, ERROR, etc.)
            user_id: User associated with this event
            details: Additional event-specific details
            latency_ms: Processing latency in milliseconds
            error: Error message if applicable
            **kwargs: Additional custom fields
        """
        event_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "session_id": self.session_id,
            "event_type": event_type.value,
            "user_id": user_id,
            "event_count": self.event_count,
            "elapsed_seconds": time.time() - self.start_time,
            "service": "RealtimeSessionLogger",
        }
        
        # Add optional fields
        if details:
            event_data["details"] = details
        if latency_ms is not None:
            event_data["latency_ms"] = latency_ms
        if error:
            event_data["error"] = error
        
        # Add any custom fields
        event_data.update(kwargs)
        
        # Increment counter
        self.event_count += 1
        
        # Log based on level
        log_func = getattr(self._event_logger, level.value.lower())
        log_func(json.dumps(event_data, ensure_ascii=False))
    
    def log_audio_chunk(
        self,
        user_id: int,
        chunk_size: int,
        sample_rate: int,
        channel: int,
        **kwargs
    ) -> None:
        """Log received audio chunk"""
        self.bytes_received += chunk_size
        self.log_event(
            event_type=SessionEventType.AUDIO_CHUNK_RECEIVED,
            user_id=user_id,
            details={
                "chunk_size_bytes": chunk_size,
                "total_bytes_received": self.bytes_received,
                "sample_rate": sample_rate,
                "channels": channel,
            },
            **kwargs
        )
    
    def log_utterance_start(
        self,
        user_id: int,
        speaker: Optional[str] = None,
        **kwargs
    ) -> None:
        """Log start of new utterance"""
        self.log_event(
            event_type=SessionEventType.UTTERANCE_STARTED,
            user_id=user_id,
            details={"speaker": speaker} if speaker else {},
            **kwargs
        )
    
    def log_utterance_end(
        self,
        user_id: int,
        duration_seconds: float,
        audio_bytes: int,
        speaker: Optional[str] = None,
        **kwargs
    ) -> None:
        """Log end of utterance"""
        self.log_event(
            event_type=SessionEventType.UTTERANCE_ENDED,
            user_id=user_id,
            details={
                "duration_seconds": duration_seconds,
                "audio_bytes": audio_bytes,
                "speaker": speaker,
            },
            **kwargs
        )
    
    def log_stt_completed(
        self,
        user_id: int,
        text: str,
        language: str,
        confidence: float,
        latency_ms: float,
        speaker: Optional[str] = None,
        **kwargs
    ) -> None:
        """Log successful STT (Speech-to-Text) processing"""
        self.log_event(
            event_type=SessionEventType.STT_COMPLETED,
            user_id=user_id,
            latency_ms=latency_ms,
            details={
                "text": text[:100],  # Log first 100 chars only
                "text_length": len(text),
                "language": language,
                "confidence": confidence,
                "speaker": speaker,
            },
            **kwargs
        )
    
    def log_stt_error(
        self,
        user_id: int,
        error_msg: str,
        latency_ms: float,
        **kwargs
    ) -> None:
        """Log STT processing error"""
        self.log_event(
            event_type=SessionEventType.STT_ERROR,
            level=SessionLogLevel.ERROR,
            user_id=user_id,
            error=error_msg,
            latency_ms=latency_ms,
            **kwargs
        )
    
    def log_translation_completed(
        self,
        user_id: int,
        source_text: str,
        translated_text: str,
        source_language: str,
        target_language: str,
        latency_ms: float,
        provider: str = "google",
        **kwargs
    ) -> None:
        """Log successful translation"""
        self.log_event(
            event_type=SessionEventType.TRANSLATION_COMPLETED,
            user_id=user_id,
            latency_ms=latency_ms,
            details={
                "source_text": source_text[:100],
                "translated_text": translated_text[:100],
                "source_language": source_language,
                "target_language": target_language,
                "provider": provider,
            },
            **kwargs
        )
    
    def log_translation_error(
        self,
        user_id: int,
        error_msg: str,
        source_language: str,
        target_language: str,
        latency_ms: float,
        **kwargs
    ) -> None:
        """Log translation error"""
        self.log_event(
            event_type=SessionEventType.TRANSLATION_ERROR,
            level=SessionLogLevel.ERROR,
            user_id=user_id,
            error=error_msg,
            details={
                "source_language": source_language,
                "target_language": target_language,
            },
            latency_ms=latency_ms,
            **kwargs
        )
    
    def log_speaker_changed(
        self,
        user_id: int,
        new_speaker: str,
        previous_speaker: Optional[str] = None,
        **kwargs
    ) -> None:
        """Log speaker change in conversation"""
        self.log_event(
            event_type=SessionEventType.SPEAKER_CHANGED,
            user_id=user_id,
            details={
                "new_speaker": new_speaker,
                "previous_speaker": previous_speaker,
            },
            **kwargs
        )
    
    def log_session_error(
        self,
        user_id: Optional[int] = None,
        error_msg: str = "",
        error_code: Optional[str] = None,
        **kwargs
    ) -> None:
        """Log critical session error"""
        self.log_event(
            event_type=SessionEventType.SESSION_ERROR,
            level=SessionLogLevel.ERROR,
            user_id=user_id,
            error=error_msg,
            details={"error_code": error_code} if error_code else {},
            **kwargs
        )
    
    def log_rate_limit_exceeded(
        self,
        user_id: int,
        limit_type: str,
        current_count: int,
        limit: int,
        reset_seconds: int,
        **kwargs
    ) -> None:
        """Log rate limit exceeded event"""
        self.log_event(
            event_type=SessionEventType.RATE_LIMIT_EXCEEDED,
            level=SessionLogLevel.WARNING,
            user_id=user_id,
            details={
                "limit_type": limit_type,  # e.g., "messages_per_minute", "audio_mb_per_hour"
                "current_count": current_count,
                "limit": limit,
                "reset_seconds": reset_seconds,
            },
            **kwargs
        )
    
    def log_session_end(
        self,
        user_id: int,
        total_duration_seconds: Optional[float] = None,
        status: str = "completed",
        **kwargs
    ) -> None:
        """Log end of session with summary"""
        if total_duration_seconds is None:
            total_duration_seconds = time.time() - self.start_time
        
        self.log_event(
            event_type=SessionEventType.SESSION_END,
            user_id=user_id,
            details={
                "status": status,
                "total_duration_seconds": total_duration_seconds,
                "total_events": self.event_count,
                "bytes_received": self.bytes_received,
                "bytes_transmitted": self.bytes_transmitted,
                "avg_event_latency_ms": (
                    (time.time() - self.start_time) * 1000 / self.event_count
                    if self.event_count > 0 else 0
                ),
            },
            **kwargs
        )
    
    def get_session_summary(self) -> Dict[str, Any]:
        """Get summary of current session"""
        duration = time.time() - self.start_time
        return {
            "session_id": self.session_id,
            "duration_seconds": duration,
            "event_count": self.event_count,
            "bytes_received": self.bytes_received,
            "bytes_transmitted": self.bytes_transmitted,
            "avg_latency_per_event_ms": (
                (duration * 1000 / self.event_count) if self.event_count > 0 else 0
            ),
        }


class ConversationSessionMetrics:
    """Track metrics for conversation sessions"""
    
    def __init__(self, session_logger: RealtimeSessionLogger):
        self.logger = session_logger
        self.total_audio_duration = 0.0
        self.total_stt_latency = 0.0
        self.total_translation_latency = 0.0
        self.stt_success_count = 0
        self.stt_error_count = 0
        self.translation_success_count = 0
        self.translation_error_count = 0
        self.speakers = set()
    
    def record_stt_success(self, latency_ms: float) -> None:
        """Record successful STT"""
        self.stt_success_count += 1
        self.total_stt_latency += latency_ms
    
    def record_stt_error(self) -> None:
        """Record STT error"""
        self.stt_error_count += 1
    
    def record_translation_success(self, latency_ms: float) -> None:
        """Record successful translation"""
        self.translation_success_count += 1
        self.total_translation_latency += latency_ms
    
    def record_translation_error(self) -> None:
        """Record translation error"""
        self.translation_error_count += 1
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get aggregated metrics"""
        return {
            "stt_success_count": self.stt_success_count,
            "stt_error_count": self.stt_error_count,
            "stt_success_rate": (
                self.stt_success_count / (self.stt_success_count + self.stt_error_count)
                if (self.stt_success_count + self.stt_error_count) > 0 else 0
            ),
            "avg_stt_latency_ms": (
                self.total_stt_latency / self.stt_success_count
                if self.stt_success_count > 0 else 0
            ),
            "translation_success_count": self.translation_success_count,
            "translation_error_count": self.translation_error_count,
            "translation_success_rate": (
                self.translation_success_count / (self.translation_success_count + self.translation_error_count)
                if (self.translation_success_count + self.translation_error_count) > 0 else 0
            ),
            "avg_translation_latency_ms": (
                self.total_translation_latency / self.translation_success_count
                if self.translation_success_count > 0 else 0
            ),
            "unique_speakers": len(self.speakers),
        }
