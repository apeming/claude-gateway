export interface User {
  id: number;
  feishu_user_id: string;
  name: string;
  avatar?: string;
  email?: string;
  role: 'admin' | 'user';
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Keyword {
  id: number;
  keyword: string;
  description?: string;
  owner_id: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Route {
  id: number;
  token: string;
  url: string;
  description?: string;
  is_active: boolean;
  created_by: number;
  created_at: string;
  updated_at: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface PaginationParams {
  skip?: number;
  limit?: number;
}
