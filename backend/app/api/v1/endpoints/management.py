"""
Management API endpoints for Database Backups and Cache Management
Requires Admin privileges
"""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import logging
from pathlib import Path

from app.core.dependencies import get_admin_user
from app.core.redis_client import get_redis_client
from app.services.backup_service import DatabaseBackupService
from app.services.static_cache_service import StaticContentCacheService
from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/management", tags=["management"])


# ==================== SCHEMAS ====================

class BackupResponse(BaseModel):
    """Response model for backup information"""
    filename: str
    size_mb: float
    created_at: str
    path: str


class BackupListResponse(BaseModel):
    """Response for list of backups"""
    count: int
    backups: List[BackupResponse]


class CacheStatsResponse(BaseModel):
    """Response for cache statistics"""
    db_size_entries: int
    memory_used_bytes: int
    memory_used_human: str
    memory_peak_bytes: int
    memory_peak_human: str
    evicted_keys: int


class MessageResponse(BaseModel):
    """Simple message response"""
    success: bool
    message: str


# ==================== DEPENDENCIES ====================

def get_backup_service() -> DatabaseBackupService:
    """Get or create backup service instance"""
    return DatabaseBackupService(
        db_url=settings.DATABASE_URL,
        backup_dir="/backups/database",
        max_backups=7,
        compress=True,
    )


async def get_cache_service() -> StaticContentCacheService:
    """Get cache service with Redis client"""
    redis_client = await get_redis_client()
    return StaticContentCacheService(redis_client)


# ==================== BACKUP ENDPOINTS ====================

@router.post(
    "/backups/create",
    response_model=MessageResponse,
    summary="Create a new database backup",
    dependencies=[Depends(get_admin_user)],
)
async def create_backup(
    background_tasks: BackgroundTasks,
    backup_name: Optional[str] = Query(None, description="Optional custom backup name"),
    backup_service: DatabaseBackupService = Depends(get_backup_service),
):
    """
    Trigger an immediate database backup.
    Runs in the background to avoid blocking.
    
    **Requires Admin privileges**
    """
    try:
        # Add backup task to background
        background_tasks.add_task(backup_service.create_backup, backup_name)
        
        return MessageResponse(
            success=True,
            message="Backup initiated. Check status in a few moments."
        )
    except Exception as e:
        logger.error(f"❌ Backup creation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to initiate backup")


@router.get(
    "/backups/list",
    response_model=BackupListResponse,
    summary="List all available backups",
    dependencies=[Depends(get_admin_user)],
)
async def list_backups(
    backup_service: DatabaseBackupService = Depends(get_backup_service),
):
    """
    Get list of all available database backups with metadata.
    
    **Requires Admin privileges**
    """
    try:
        backups = await backup_service.get_backup_list()
        
        return BackupListResponse(
            count=len(backups),
            backups=[BackupResponse(**backup) for backup in backups]
        )
    except Exception as e:
        logger.error(f"❌ List backups error: {e}")
        raise HTTPException(status_code=500, detail="Failed to list backups")


@router.delete(
    "/backups/{backup_filename}",
    response_model=MessageResponse,
    summary="Delete a backup file",
    dependencies=[Depends(get_admin_user)],
)
async def delete_backup(
    backup_filename: str,
    backup_service: DatabaseBackupService = Depends(get_backup_service),
):
    """
    Delete a specific backup file.
    
    **Requires Admin privileges**
    """
    try:
        success = await backup_service.delete_backup(backup_filename)
        
        if not success:
            raise HTTPException(status_code=404, detail="Backup not found")
        
        return MessageResponse(
            success=True,
            message=f"Backup '{backup_filename}' deleted successfully"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Delete backup error: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete backup")


@router.post(
    "/backups/{backup_filename}/restore",
    response_model=MessageResponse,
    summary="Restore database from a backup",
    dependencies=[Depends(get_admin_user)],
)
async def restore_backup(
    backup_filename: str,
    background_tasks: BackgroundTasks,
    backup_service: DatabaseBackupService = Depends(get_backup_service),
):
    """
    ⚠️ WARNING: Restore will overwrite the current database!
    Runs in the background. Database may be temporarily unavailable.
    
    **Requires Admin privileges**
    """
    try:
        # Validate backup exists
        backups = await backup_service.get_backup_list()
        backup_exists = any(b["filename"] == backup_filename for b in backups)
        
        if not backup_exists:
            raise HTTPException(status_code=404, detail="Backup not found")
        
        # Run restoration in background
        backup_path = backup_service.backup_dir / backup_filename
        background_tasks.add_task(backup_service.restore_backup, backup_path)
        
        return MessageResponse(
            success=True,
            message="Database restoration started. This may take several minutes. "
                   "The application will be temporarily unavailable."
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Restore backup error: {e}")
        raise HTTPException(status_code=500, detail="Failed to initiate restoration")


# ==================== CACHE ENDPOINTS ====================

@router.get(
    "/cache/stats",
    response_model=CacheStatsResponse,
    summary="Get Redis cache statistics",
    dependencies=[Depends(get_admin_user)],
)
async def get_cache_stats(
    cache_service: StaticContentCacheService = Depends(get_cache_service),
):
    """
    Get current Redis cache statistics including memory usage and key counts.
    
    **Requires Admin privileges**
    """
    try:
        stats = await cache_service.get_cache_stats()
        
        if not stats:
            raise HTTPException(status_code=503, detail="Redis not available")
        
        return CacheStatsResponse(**stats)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Cache stats error: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve cache stats")


@router.delete(
    "/cache/clear",
    response_model=MessageResponse,
    summary="Clear all cache entries",
    dependencies=[Depends(get_admin_user)],
)
async def clear_all_cache(
    cache_service: StaticContentCacheService = Depends(get_cache_service),
):
    """
    Clear all cache entries. This will force regeneration on next request.
    
    **Requires Admin privileges**
    """
    try:
        deleted = await cache_service.clear_cache_by_pattern("*")
        
        return MessageResponse(
            success=True,
            message=f"Cleared {deleted} cache entries"
        )
    except Exception as e:
        logger.error(f"❌ Clear cache error: {e}")
        raise HTTPException(status_code=500, detail="Failed to clear cache")


@router.delete(
    "/cache/clear/{prefix}",
    response_model=MessageResponse,
    summary="Clear cache by prefix",
    dependencies=[Depends(get_admin_user)],
)
async def clear_cache_by_prefix(
    prefix: str = Query(..., description="Cache prefix (e.g., 'api_response:', 'vocabulary:')"),
    cache_service: StaticContentCacheService = Depends(get_cache_service),
):
    """
    Clear cache entries by prefix pattern.
    
    Supported prefixes:
    - `static:` - Static file cache
    - `api_response:` - API response cache
    - `config:` - Configuration cache
    - `vocabulary:` - Vocabulary cache
    - `languages:` - Language list cache
    
    **Requires Admin privileges**
    """
    try:
        pattern = f"{prefix}*"
        deleted = await cache_service.clear_cache_by_pattern(pattern)
        
        return MessageResponse(
            success=True,
            message=f"Cleared {deleted} cache entries with prefix '{prefix}'"
        )
    except Exception as e:
        logger.error(f"❌ Clear cache by prefix error: {e}")
        raise HTTPException(status_code=500, detail="Failed to clear cache")


@router.post(
    "/cache/prefetch/languages",
    response_model=MessageResponse,
    summary="Prefetch languages into cache",
    dependencies=[Depends(get_admin_user)],
)
async def prefetch_languages(
    background_tasks: BackgroundTasks,
    cache_service: StaticContentCacheService = Depends(get_cache_service),
):
    """
    Prefetch supported languages into cache.
    
    **Requires Admin privileges**
    """
    try:
        # TODO: Get actual language list from database
        # For now, this is a placeholder
        languages = [
            {"code": "en", "name": "English"},
            {"code": "vi", "name": "Tiếng Việt"},
            {"code": "zh", "name": "中文"},
            {"code": "ja", "name": "日本語"},
            {"code": "ko", "name": "한국어"},
        ]
        
        background_tasks.add_task(
            cache_service.cache_language_list,
            languages
        )
        
        return MessageResponse(
            success=True,
            message="Language prefetch initiated"
        )
    except Exception as e:
        logger.error(f"❌ Prefetch languages error: {e}")
        raise HTTPException(status_code=500, detail="Failed to prefetch languages")


@router.get(
    "/health/backup",
    response_model=MessageResponse,
    summary="Check backup system health",
)
async def check_backup_health(
    backup_service: DatabaseBackupService = Depends(get_backup_service),
):
    """
    Check if backup system is operational and directory is accessible.
    """
    try:
        backups = await backup_service.get_backup_list()
        
        return MessageResponse(
            success=True,
            message=f"Backup system operational. {len(backups)} backups available."
        )
    except Exception as e:
        return MessageResponse(
            success=False,
            message=f"Backup system issue: {str(e)}"
        )


@router.get(
    "/health/cache",
    response_model=MessageResponse,
    summary="Check cache system health",
)
async def check_cache_health(
    cache_service: StaticContentCacheService = Depends(get_cache_service),
):
    """
    Check if Redis cache is operational.
    """
    try:
        stats = await cache_service.get_cache_stats()
        
        if not stats:
            return MessageResponse(
                success=False,
                message="Redis cache not responding"
            )
        
        return MessageResponse(
            success=True,
            message="Cache system operational"
        )
    except Exception as e:
        return MessageResponse(
            success=False,
            message=f"Cache system issue: {str(e)}"
        )
