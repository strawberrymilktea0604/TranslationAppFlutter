"""
Database Backup Service using pg_dump
Handles automated and manual database backups with compression and retention policies.
"""
import os
import logging
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, List
import subprocess
import gzip
import shutil

logger = logging.getLogger(__name__)


class DatabaseBackupService:
    """Service for managing PostgreSQL database backups"""
    
    def __init__(
        self,
        db_url: str,
        backup_dir: str = "/backups/database",
        max_backups: int = 7,
        compress: bool = True,
    ):
        """
        Initialize backup service.
        
        Args:
            db_url: PostgreSQL connection string
            backup_dir: Directory to store backups
            max_backups: Number of backups to keep (default: 7 for a week)
            compress: Whether to compress backups with gzip
        """
        self.db_url = db_url
        self.backup_dir = Path(backup_dir)
        self.max_backups = max_backups
        self.compress = compress
        
        # Create backup directory
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"🔧 Backup service initialized - Directory: {self.backup_dir}")
    
    def _parse_db_url(self) -> Dict[str, str]:
        """
        Parse PostgreSQL connection URL to extract connection parameters.
        Format: postgresql://user:password@host:port/dbname
        """
        try:
            # Remove scheme
            url = self.db_url.replace("postgresql://", "").replace("postgresql+asyncpg://", "")
            
            # Split user and host parts
            if "@" in url:
                user_pass, host_part = url.rsplit("@", 1)
                user, password = user_pass.split(":", 1) if ":" in user_pass else (user_pass, "")
            else:
                user = "postgres"
                password = ""
                host_part = url
            
            # Split host and database
            if "/" in host_part:
                host_port, dbname = host_part.rsplit("/", 1)
            else:
                host_port = host_part
                dbname = "postgres"
            
            # Split host and port
            if ":" in host_port:
                host, port = host_port.rsplit(":", 1)
            else:
                host = host_port
                port = "5432"
            
            return {
                "host": host,
                "port": port,
                "user": user,
                "password": password,
                "dbname": dbname,
            }
        except Exception as e:
            logger.error(f"❌ Failed to parse database URL: {e}")
            raise
    
    async def create_backup(self, backup_name: Optional[str] = None) -> Optional[Path]:
        """
        Create a database backup using pg_dump.
        
        Args:
            backup_name: Optional custom backup name (default: timestamp)
        
        Returns:
            Path to the backup file or None if failed
        """
        try:
            db_params = self._parse_db_url()
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = backup_name or f"backup_{timestamp}"
            backup_file = self.backup_dir / f"{backup_name}.sql"
            
            logger.info(f"⏳ Starting database backup: {backup_name}")
            
            # Prepare pg_dump command
            cmd = [
                "pg_dump",
                "-h", db_params["host"],
                "-p", db_params["port"],
                "-U", db_params["user"],
                "-F", "c",  # Custom format (compressed)
                "-v",  # Verbose
                "-d", db_params["dbname"],
                "-f", str(backup_file),
            ]
            
            # Set password in environment if provided
            env = os.environ.copy()
            if db_params["password"]:
                env["PGPASSWORD"] = db_params["password"]
            
            # Run pg_dump
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=env,
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode()
                logger.error(f"❌ Backup failed: {error_msg}")
                return None
            
            # Get file size
            file_size = backup_file.stat().st_size
            file_size_mb = file_size / (1024 * 1024)
            
            logger.info(f"✅ Backup created successfully: {backup_name} ({file_size_mb:.2f} MB)")
            
            # Additional gzip compression if enabled
            if self.compress:
                await self._compress_backup(backup_file)
            
            # Clean old backups
            await self._cleanup_old_backups()
            
            return backup_file
            
        except FileNotFoundError:
            logger.error("❌ pg_dump not found. Ensure PostgreSQL client tools are installed.")
            return None
        except Exception as e:
            logger.error(f"❌ Backup creation error: {e}")
            return None
    
    async def _compress_backup(self, backup_file: Path) -> None:
        """Compress backup file with gzip"""
        try:
            compressed_file = Path(str(backup_file) + ".gz")
            
            def compress():
                with open(backup_file, "rb") as f_in:
                    with gzip.open(compressed_file, "wb") as f_out:
                        shutil.copyfileobj(f_in, f_out)
            
            await asyncio.to_thread(compress)
            
            # Remove original file
            backup_file.unlink()
            
            logger.info(f"✅ Backup compressed: {compressed_file.name}")
            
        except Exception as e:
            logger.error(f"❌ Compression failed: {e}")
    
    async def _cleanup_old_backups(self) -> None:
        """Remove old backups exceeding max_backups limit"""
        try:
            backup_files = sorted(self.backup_dir.glob("backup_*.sql*"))
            
            if len(backup_files) > self.max_backups:
                # Remove oldest backups
                for old_backup in backup_files[:-self.max_backups]:
                    old_backup.unlink()
                    logger.info(f"🗑️  Removed old backup: {old_backup.name}")
                    
        except Exception as e:
            logger.error(f"❌ Cleanup failed: {e}")
    
    async def restore_backup(self, backup_file: Path) -> bool:
        """
        Restore database from a backup file.
        ⚠️ WARNING: This will overwrite the current database!
        
        Args:
            backup_file: Path to the backup file
        
        Returns:
            True if restoration successful, False otherwise
        """
        try:
            db_params = self._parse_db_url()
            
            # Check if file exists
            if not backup_file.exists():
                logger.error(f"❌ Backup file not found: {backup_file}")
                return False
            
            logger.warning(f"⚠️  Starting database restoration from: {backup_file.name}")
            
            # Prepare pg_restore command
            cmd = [
                "pg_restore",
                "-h", db_params["host"],
                "-p", db_params["port"],
                "-U", db_params["user"],
                "-d", db_params["dbname"],
                "-v",
                "--clean",  # Drop objects before recreating
                str(backup_file),
            ]
            
            # Set password in environment if provided
            env = os.environ.copy()
            if db_params["password"]:
                env["PGPASSWORD"] = db_params["password"]
            
            # Run pg_restore
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=env,
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode()
                logger.error(f"❌ Restoration failed: {error_msg}")
                return False
            
            logger.info(f"✅ Database restored successfully from: {backup_file.name}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Restoration error: {e}")
            return False
    
    async def get_backup_list(self) -> List[Dict[str, str]]:
        """Get list of all available backups with metadata"""
        try:
            backups = []
            backup_files = sorted(
                self.backup_dir.glob("backup_*"),
                key=lambda x: x.stat().st_mtime,
                reverse=True
            )
            
            for backup_file in backup_files:
                stat = backup_file.stat()
                backups.append({
                    "filename": backup_file.name,
                    "size_mb": round(stat.st_size / (1024 * 1024), 2),
                    "created_at": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    "path": str(backup_file),
                })
            
            return backups
            
        except Exception as e:
            logger.error(f"❌ Failed to list backups: {e}")
            return []
    
    async def delete_backup(self, backup_filename: str) -> bool:
        """Delete a specific backup file"""
        try:
            backup_file = self.backup_dir / backup_filename
            
            if not backup_file.exists():
                logger.error(f"❌ Backup not found: {backup_filename}")
                return False
            
            backup_file.unlink()
            logger.info(f"🗑️  Deleted backup: {backup_filename}")
            return True
            
        except Exception as e:
            logger.error(f"❌ Delete failed: {e}")
            return False


class BackupScheduler:
    """Scheduler for automated database backups"""
    
    def __init__(self, backup_service: DatabaseBackupService):
        """Initialize scheduler with backup service"""
        self.backup_service = backup_service
        self.scheduler = None
    
    def initialize_scheduler(self):
        """Initialize APScheduler for automated backups"""
        try:
            from apscheduler.schedulers.asyncio import AsyncIOScheduler
            from apscheduler.triggers.cron import CronTrigger
            
            self.scheduler = AsyncIOScheduler()
            
            # Schedule daily backup at 2 AM
            self.scheduler.add_job(
                self.backup_service.create_backup,
                trigger=CronTrigger(hour=2, minute=0),
                id="daily_backup",
                name="Daily Database Backup",
                replace_existing=True,
            )
            
            logger.info("✅ Backup scheduler initialized (Daily at 2:00 AM)")
            
        except ImportError:
            logger.warning("⚠️  APScheduler not installed. Skipping scheduler initialization.")
        except Exception as e:
            logger.error(f"❌ Scheduler initialization failed: {e}")
    
    def start(self):
        """Start the scheduler"""
        if self.scheduler:
            self.scheduler.start()
            logger.info("🚀 Backup scheduler started")
    
    def stop(self):
        """Stop the scheduler"""
        if self.scheduler and self.scheduler.running:
            self.scheduler.shutdown()
            logger.info("🛑 Backup scheduler stopped")
