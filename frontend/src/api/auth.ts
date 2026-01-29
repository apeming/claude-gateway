import request from '@/utils/request';
import { User, LoginResponse } from '@/types';

export const feishuCallback = (code: string): Promise<LoginResponse> => {
  return request.post('/auth/feishu/callback', { code });
};

export const getCurrentUser = (): Promise<User> => {
  return request.get('/auth/me');
};
