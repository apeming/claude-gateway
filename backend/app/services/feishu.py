import httpx
from typing import Optional
from app.config import settings
from app.schemas import FeishuUserInfo


class FeishuOAuthService:
    """飞书OAuth服务"""

    def __init__(self):
        self.app_id = settings.FEISHU_APP_ID
        self.app_secret = settings.FEISHU_APP_SECRET
        self.redirect_uri = settings.FEISHU_REDIRECT_URI

    async def get_app_access_token(self) -> Optional[str]:
        """获取应用访问令牌"""
        url = "https://open.feishu.cn/open-apis/auth/v3/app_access_token/internal"
        data = {
            "app_id": self.app_id,
            "app_secret": self.app_secret
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(url, json=data)
                result = response.json()
                if result.get("code") == 0:
                    return result.get("app_access_token")
                return None
            except Exception:
                return None

    async def get_user_access_token(self, code: str) -> Optional[str]:
        """通过授权码获取用户访问令牌"""
        app_access_token = await self.get_app_access_token()
        if not app_access_token:
            return None

        url = "https://open.feishu.cn/open-apis/authen/v1/access_token"
        headers = {
            "Authorization": f"Bearer {app_access_token}",
            "Content-Type": "application/json"
        }
        data = {
            "grant_type": "authorization_code",
            "code": code
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(url, headers=headers, json=data)
                result = response.json()
                if result.get("code") == 0:
                    return result.get("data", {}).get("access_token")
                return None
            except Exception:
                return None

    async def get_user_info(self, user_access_token: str) -> Optional[FeishuUserInfo]:
        """获取用户信息"""
        url = "https://open.feishu.cn/open-apis/authen/v1/user_info"
        headers = {
            "Authorization": f"Bearer {user_access_token}"
        }

        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers)
                result = response.json()
                if result.get("code") == 0:
                    data = result.get("data", {})
                    return FeishuUserInfo(
                        user_id=data.get("open_id"),
                        name=data.get("name", ""),
                        avatar=data.get("avatar_url"),
                        email=data.get("email")
                    )
                return None
            except Exception:
                return None


feishu_oauth_service = FeishuOAuthService()
