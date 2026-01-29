from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.database import get_db
from app.models import User
from app.schemas import FeishuAuthRequest, Token, UserResponse
from app.services.feishu import feishu_oauth_service
from app.utils.auth import create_access_token, get_current_user

router = APIRouter(prefix="/auth", tags=["认证"])


@router.post("/feishu/callback", response_model=Token)
async def feishu_callback(
    auth_request: FeishuAuthRequest,
    db: AsyncSession = Depends(get_db)
):
    """飞书OAuth回调"""
    # 获取用户访问令牌
    user_access_token = await feishu_oauth_service.get_user_access_token(auth_request.code)
    if not user_access_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to get user access token"
        )

    # 获取用户信息
    feishu_user_info = await feishu_oauth_service.get_user_info(user_access_token)
    if not feishu_user_info:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to get user info"
        )

    # 查找或创建用户
    result = await db.execute(
        select(User).where(User.feishu_user_id == feishu_user_info.user_id)
    )
    user = result.scalar_one_or_none()

    if not user:
        # 检查是否是第一个用户(自动设为管理员)
        count_result = await db.execute(select(func.count(User.id)))
        user_count = count_result.scalar()

        user = User(
            feishu_user_id=feishu_user_info.user_id,
            name=feishu_user_info.name,
            avatar=feishu_user_info.avatar,
            email=feishu_user_info.email,
            role="admin" if user_count == 0 else "user"
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    else:
        # 更新用户信息
        user.name = feishu_user_info.name
        user.avatar = feishu_user_info.avatar
        user.email = feishu_user_info.email
        await db.commit()

    # 创建访问令牌
    access_token = create_access_token(data={"sub": user.id})

    return Token(access_token=access_token)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """获取当前用户信息"""
    return current_user
