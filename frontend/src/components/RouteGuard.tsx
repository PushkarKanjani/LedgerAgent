import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { getAuthToken } from '../services/api';

export const RouteGuard: React.FC = () => {
  const token = getAuthToken();

  if (!token) {
    return <Navigate to="/app/login" replace />;
  }

  return <Outlet />;
};
