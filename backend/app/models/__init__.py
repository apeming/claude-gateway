from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime

Base = declarative_base()


class User(Base):
    """用户表"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    feishu_user_id = Column(String(100), unique=True, index=True, nullable=False, comment="飞书用户ID")
    name = Column(String(100), nullable=False, comment="用户名")
    avatar = Column(String(500), comment="头像URL")
    email = Column(String(100), comment="邮箱")
    role = Column(String(20), default="user", nullable=False, comment="角色: admin/user")
    is_active = Column(Boolean, default=True, nullable=False, comment="是否激活")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关系
    keywords = relationship("Keyword", back_populates="owner", cascade="all, delete-orphan")


class Keyword(Base):
    """关键字表"""
    __tablename__ = "keywords"

    id = Column(Integer, primary_key=True, index=True)
    keyword = Column(String(500), nullable=False, index=True, comment="关键字内容")
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, comment="所属用户ID")
    description = Column(Text, comment="关键字描述")
    is_active = Column(Boolean, default=True, nullable=False, comment="是否启用")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # 关系
    owner = relationship("User", back_populates="keywords")


class Route(Base):
    """路由表"""
    __tablename__ = "routes"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String(200), unique=True, nullable=False, index=True, comment="路由token")
    url = Column(String(500), nullable=False, comment="上游URL")
    description = Column(Text, comment="路由描述")
    is_active = Column(Boolean, default=True, nullable=False, comment="是否启用")
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False, comment="创建者ID")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
