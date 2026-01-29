from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# 用户相关schemas
class UserBase(BaseModel):
    name: str
    email: Optional[str] = None
    role: str = "user"


class UserCreate(UserBase):
    feishu_user_id: str


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None


class UserResponse(UserBase):
    id: int
    feishu_user_id: str
    avatar: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# 关键字相关schemas
class KeywordBase(BaseModel):
    keyword: str = Field(..., min_length=1, max_length=500)
    description: Optional[str] = None
    is_active: bool = True


class KeywordCreate(KeywordBase):
    pass


class KeywordUpdate(BaseModel):
    keyword: Optional[str] = Field(None, min_length=1, max_length=500)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class KeywordResponse(KeywordBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# 路由相关schemas
class RouteBase(BaseModel):
    token: str = Field(..., min_length=1, max_length=200)
    url: str = Field(..., min_length=1, max_length=500)
    description: Optional[str] = None
    is_active: bool = True


class RouteCreate(RouteBase):
    pass


class RouteUpdate(BaseModel):
    token: Optional[str] = Field(None, min_length=1, max_length=200)
    url: Optional[str] = Field(None, min_length=1, max_length=500)
    description: Optional[str] = None
    is_active: Optional[bool] = None


class RouteResponse(RouteBase):
    id: int
    created_by: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# 认证相关schemas
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class FeishuAuthRequest(BaseModel):
    code: str


class FeishuUserInfo(BaseModel):
    user_id: str
    name: str
    avatar: Optional[str] = None
    email: Optional[str] = None
