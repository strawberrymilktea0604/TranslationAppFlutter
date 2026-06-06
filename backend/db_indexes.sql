-- PostgreSQL performance indexes and extensions for TranslationApp
-- This file is safe to rerun; all index creation statements use IF NOT EXISTS.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_translations_user_created_at
ON translations(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_translations_user_lang_pair_created_at
ON translations(user_id, source_language, target_language, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_translations_user_deleted_created_at
ON translations(user_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_translations_source_text_trgm
ON translations USING gin (source_text gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_translations_translated_text_trgm
ON translations USING gin (translated_text gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_translations_exact_lookup
ON translations(user_id, source_language, target_language, source_text, is_deleted);

CREATE INDEX IF NOT EXISTS idx_vocabularies_user_deleted_created_at
ON vocabularies(user_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_vocabularies_user_sync_client_id
ON vocabularies(user_id, sync_client_id);

CREATE INDEX IF NOT EXISTS idx_vocabularies_category_id
ON vocabularies(category_id);

CREATE INDEX IF NOT EXISTS idx_vocabulary_categories_user_id
ON vocabulary_categories(user_id);

CREATE INDEX IF NOT EXISTS idx_conversation_sessions_user_id
ON conversation_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_conversation_sessions_session_uuid
ON conversation_sessions(session_uuid);

CREATE INDEX IF NOT EXISTS idx_conversation_messages_session_id
ON conversation_messages(session_id);

CREATE INDEX IF NOT EXISTS idx_api_metrics_user_created_at
ON api_metrics(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_api_metrics_endpoint_created_at
ON api_metrics(endpoint, created_at DESC);
