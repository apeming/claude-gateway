import React, { useEffect, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { Layout as AntLayout, Menu, Avatar, Dropdown, message } from 'antd';
import { UserOutlined, KeyOutlined, ApiOutlined, TeamOutlined, LogoutOutlined } from '@ant-design/icons';
import { getCurrentUser } from '@/api/auth';
import { removeToken } from '@/utils/auth';
import type { User } from '@/types';

const { Header, Sider, Content } = AntLayout;

const Layout: React.FC = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    loadUser();
  }, []);

  const loadUser = async () => {
    try {
      const userData = await getCurrentUser();
      setUser(userData);
    } catch (error) {
      message.error('获取用户信息失败');
    }
  };

  const handleLogout = () => {
    removeToken();
    navigate('/login');
  };

  const menuItems = [
    {
      key: '/keywords',
      icon: <KeyOutlined />,
      label: '关键字管理',
      onClick: () => navigate('/keywords'),
    },
    ...(user?.role === 'admin'
      ? [
          {
            key: '/routes',
            icon: <ApiOutlined />,
            label: '路由管理',
            onClick: () => navigate('/routes'),
          },
          {
            key: '/users',
            icon: <TeamOutlined />,
            label: '用户管理',
            onClick: () => navigate('/users'),
          },
        ]
      : []),
  ];

  const userMenuItems = [
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: '退出登录',
      onClick: handleLogout,
    },
  ];

  return (
    <AntLayout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#001529' }}>
        <div style={{ color: 'white', fontSize: '20px', fontWeight: 'bold' }}>Claude Gateway</div>
        <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
          <div style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Avatar src={user?.avatar} icon={<UserOutlined />} />
            <span style={{ color: 'white' }}>{user?.name}</span>
          </div>
        </Dropdown>
      </Header>
      <AntLayout>
        <Sider width={200} style={{ background: '#fff' }}>
          <Menu mode="inline" style={{ height: '100%', borderRight: 0 }} items={menuItems} defaultSelectedKeys={['/keywords']} />
        </Sider>
        <AntLayout style={{ padding: '24px' }}>
          <Content style={{ background: '#fff', padding: 24, margin: 0, minHeight: 280 }}>
            <Outlet />
          </Content>
        </AntLayout>
      </AntLayout>
    </AntLayout>
  );
};

export default Layout;
