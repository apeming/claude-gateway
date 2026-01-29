import aiofiles
from typing import List
from app.config import settings


class FileSyncService:
    """文件同步服务 - 同步数据库和OpenResty配置文件"""

    @staticmethod
    async def sync_keywords_to_file(keywords: List[str]):
        """同步关键字到文件"""
        try:
            async with aiofiles.open(settings.KEYWORDS_FILE, 'w', encoding='utf-8') as f:
                for keyword in keywords:
                    await f.write(f"{keyword}\n")
            return True
        except Exception as e:
            print(f"Error syncing keywords to file: {e}")
            return False

    @staticmethod
    async def sync_routes_to_file(routes: List[tuple]):
        """同步路由到文件
        Args:
            routes: List of (token, url) tuples
        """
        try:
            async with aiofiles.open(settings.ROUTES_FILE, 'w', encoding='utf-8') as f:
                for token, url in routes:
                    await f.write(f"{token} {url}\n")
            return True
        except Exception as e:
            print(f"Error syncing routes to file: {e}")
            return False


file_sync_service = FileSyncService()
