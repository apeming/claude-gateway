from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import List

from app.database import get_db
from app.models import User, Keyword
from app.schemas import KeywordCreate, KeywordUpdate, KeywordResponse
from app.utils.auth import get_current_user, get_current_admin_user
from app.services.file_sync import file_sync_service

router = APIRouter(prefix="/keywords", tags=["关键字管理"])


@router.get("", response_model=List[KeywordResponse])
async def list_keywords(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取关键字列表(普通用户只能看到自己的)"""
    if current_user.role == "admin":
        # 管理员可以看到所有关键字
        result = await db.execute(
            select(Keyword)
            .where(Keyword.is_active == True)
            .offset(skip)
            .limit(limit)
        )
    else:
        # 普通用户只能看到自己的关键字
        result = await db.execute(
            select(Keyword)
            .where(and_(Keyword.owner_id == current_user.id, Keyword.is_active == True))
            .offset(skip)
            .limit(limit)
        )

    keywords = result.scalars().all()
    return keywords


@router.post("", response_model=KeywordResponse, status_code=status.HTTP_201_CREATED)
async def create_keyword(
    keyword_data: KeywordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """创建关键字"""
    # 检查关键字是否已存在
    result = await db.execute(
        select(Keyword).where(
            and_(
                Keyword.keyword == keyword_data.keyword,
                Keyword.is_active == True
            )
        )
    )
    existing_keyword = result.scalar_one_or_none()
    if existing_keyword:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Keyword already exists"
        )

    # 创建关键字
    keyword = Keyword(
        keyword=keyword_data.keyword,
        description=keyword_data.description,
        is_active=keyword_data.is_active,
        owner_id=current_user.id
    )
    db.add(keyword)
    await db.commit()
    await db.refresh(keyword)

    # 同步到文件
    await sync_keywords_to_file(db)

    return keyword


@router.get("/{keyword_id}", response_model=KeywordResponse)
async def get_keyword(
    keyword_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取关键字详情"""
    result = await db.execute(
        select(Keyword).where(Keyword.id == keyword_id)
    )
    keyword = result.scalar_one_or_none()

    if not keyword:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Keyword not found"
        )

    # 权限检查:普通用户只能查看自己的关键字
    if current_user.role != "admin" and keyword.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    return keyword


@router.put("/{keyword_id}", response_model=KeywordResponse)
async def update_keyword(
    keyword_id: int,
    keyword_data: KeywordUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """更新关键字"""
    result = await db.execute(
        select(Keyword).where(Keyword.id == keyword_id)
    )
    keyword = result.scalar_one_or_none()

    if not keyword:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Keyword not found"
        )

    # 权限检查:普通用户只能更新自己的关键字
    if current_user.role != "admin" and keyword.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    # 更新字段
    if keyword_data.keyword is not None:
        keyword.keyword = keyword_data.keyword
    if keyword_data.description is not None:
        keyword.description = keyword_data.description
    if keyword_data.is_active is not None:
        keyword.is_active = keyword_data.is_active

    await db.commit()
    await db.refresh(keyword)

    # 同步到文件
    await sync_keywords_to_file(db)

    return keyword


@router.delete("/{keyword_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_keyword(
    keyword_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """删除关键字(软删除)"""
    result = await db.execute(
        select(Keyword).where(Keyword.id == keyword_id)
    )
    keyword = result.scalar_one_or_none()

    if not keyword:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Keyword not found"
        )

    # 权限检查:普通用户只能删除自己的关键字
    if current_user.role != "admin" and keyword.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    # 软删除
    keyword.is_active = False
    await db.commit()

    # 同步到文件
    await sync_keywords_to_file(db)


async def sync_keywords_to_file(db: AsyncSession):
    """同步所有激活的关键字到文件"""
    result = await db.execute(
        select(Keyword.keyword).where(Keyword.is_active == True)
    )
    keywords = [row[0] for row in result.all()]
    await file_sync_service.sync_keywords_to_file(keywords)
