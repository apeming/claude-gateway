import axios, { AxiosError } from 'axios';
import { message } from 'antd';
import { getToken, removeToken } from './auth';

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 30000,
});

request.interceptors.request.use(
  (config) => {
    const token = getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

request.interceptors.response.use(
  (response) => {
    return response.data;
  },
  (error: AxiosError<{ detail: string }>) => {
    if (error.response) {
      const { status, data } = error.response;

      if (status === 401) {
        message.error('登录已过期,请重新登录');
        removeToken();
        window.location.href = '/login';
      } else if (status === 403) {
        message.error('权限不足');
      } else if (status === 404) {
        message.error('资源不存在');
      } else {
        message.error(data?.detail || '请求失败');
      }
    } else {
      message.error('网络错误');
    }

    return Promise.reject(error);
  }
);

export default request;
