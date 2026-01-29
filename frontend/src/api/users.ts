import request from '@/utils/request';
import { User, PaginationParams } from '@/types';

export const getUsers = (params?: PaginationParams): Promise<User[]> => {
  return request.get('/users', { params });
};

export const updateUser = (id: number, data: Partial<User>): Promise<User> => {
  return request.put(`/users/${id}`, data);
};

export const deleteUser = (id: number): Promise<void> => {
  return request.delete(`/users/${id}`);
};
