import request from '@/utils/request';
import { Route, PaginationParams } from '@/types';

export const getRoutes = (params?: PaginationParams): Promise<Route[]> => {
  return request.get('/routes', { params });
};

export const createRoute = (data: Partial<Route>): Promise<Route> => {
  return request.post('/routes', data);
};

export const updateRoute = (id: number, data: Partial<Route>): Promise<Route> => {
  return request.put(`/routes/${id}`, data);
};

export const deleteRoute = (id: number): Promise<void> => {
  return request.delete(`/routes/${id}`);
};
