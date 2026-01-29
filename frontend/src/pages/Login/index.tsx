import React, { useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button, Card, message } from 'antd';
import { feishuCallback } from '@/api/auth';
import { setToken } from '@/utils/auth';

const Login: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    const code = searchParams.get('code');
    if (code) {
      handleCallback(code);
    }
  }, [searchParams]);

  const handleCallback = async (code: string) => {
    try {
      const res = await feishuCallback(code);
      setToken(res.access_token);
      message.success('登录成功');
      navigate('/');
    } catch (error) {
      message.error('登录失败');
    }
  };

  const handleLogin = () => {
    const appId = import.meta.env.VITE_FEISHU_APP_ID;
    const redirectUri = encodeURIComponent(window.location.origin + '/login');
    const state = Math.random().toString(36).substring(7);
    const url = `https://open.feishu.cn/open-apis/authen/v1/authorize?app_id=${appId}&redirect_uri=${redirectUri}&state=${state}`;
    window.location.href = url;
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', background: '#f0f2f5' }}>
      <Card title="Claude Gateway 管理后台" style={{ width: 400 }}>
        <Button type="primary" block size="large" onClick={handleLogin}>
          飞书登录
        </Button>
      </Card>
    </div>
  );
};

export default Login;
