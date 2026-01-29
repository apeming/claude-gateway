from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.database import get_db
from app.models import User, Route
from app.schemas import RouteCreate, RouteUpdate, RouteResponse
from app.utils.auth import get_current_admin_user
from app.services.file_sync import file_sync_service

router = APIRouter(prefix="/routes", tags=["路由管理"])


@router.get("", response_model=List[RouteResponse])
async def list_routes(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(get_current_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """获取路由列表(仅管理员)"""
    result = await db.execute(
        select(Route)
        .where(Route.is_active == True)
        .offset(skip)
        .limit(limit)
    )
    routes = result.scalars().all()
    return routes


@router.post("", response_model=RouteResponse, status_code=status.HTTP_201_CREATED)
async def create_route(
    route_data: RouteCreate,
    current_user: User = Depends(get_current_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """创建路由(仅管理员)"""
    # 检查token是否已存在
    result = await db.execute(
        select(Route).where(Route.token == route_data.token)
    )
    existing_route = result.scalar_one_or_none()
    if existing_route:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Route token already exists"
        )

    # 创建路由
    route = Route(
        token=route_data.token,
        url=route_data.url,
        description=route_data.description,
        is_active=route_data.is_active,
        created_by=current_user.id
    )
    db.add(route)
    await db.commit()
    await db.refresh(route)

    # 同步到文件
    await sync_routes_to_file(db)

    return route


@router.get("/{route_id}", response_model=RouteResponse)
async def get_route(
    route_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """获取路由详情(仅管理员)"""
    result = await db.execute(
        select(Route).where(Route.id == route_id)
    )
    route = result.scalar_one_or_none()

    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found"
        )

    return route


@router.put("/{route_id}", response_model=RouteResponse)
async def update_route(
    route_id: int,
    route_data: RouteUpdate,
    current_user: User = Depends(get_current_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """更新路由(仅管理员)"""
    result = await db.execute(
        select(Route).where(Route.id == route_id)
    )
    route = result.scalar_one_or_none()

    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found"
        )

    # 更新字段
    if route_data.token is not None:
        # 检查新token是否已被使用
        check_result = await db.execute(
            select(Route).where(Route.token == route_data.token, Route.id != route_id)
        )
        if check_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Route token already exists"
            )
        route.token = route_data.token

    if route_data.url is not None:
        route.url = route_data.url
    if route_data.description is not None:
        route.description = route_data.description
    if route_data.is_active is not None:
        route.is_active = route_data.is_active

    await db.commit()
    await db.refresh(route)

    # 同步到文件
    await sync_routes_to_file(db)

    return route


@router.delete("/{route_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_route(
    route_id: int,
    current_user: User = Depends(get_current_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """删除路由(软删除,仅管理员)"""
    result = await db.execute(
        select(Route).where(Route.id == route_id)
    )
    route = result.scalar_one_or_none()

    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found"
        )

    # 软删除
    route.is_active = False
    await db.commit()

    # 同步到文件
    await sync_routes_to_file(db)


async def sync_routes_to_file(db: AsyncSession):
    """同步所有激活的路由到文件"""
    result = await db.execute(
        select(Route.token, Route.url).where(Route.is_active == True)
    )
    routes = [(row[0], row[1]) for row in result.all()]
    await file_sync_service.sync_routes_to_file(routes)
