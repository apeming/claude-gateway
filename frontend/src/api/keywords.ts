import request from '@/utils/request';
import { Keyword, PaginationParams } from '@/types';

export const getKeywords = (params?: PaginationParams): Promise<Keyword[]> => {
  return request.get('/keywords', { params });
};

export const createKeyword = (data: Partial<Keyword>): Promise<Keyword> => {
  return request.post('/keywords', data);
};

export const updateKeyword = (id: number, data: Partial<Keyword>): Promise<Keyword> => {
  return request.put(`/keywords/${id}`, data);
};

export const deleteKeyword = (id: number): Promise<void> => {
  return request.delete(`/keywords/${id}`);
};
