import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider } from './context/ThemeContext';
import { LandingPage } from './pages/LandingPage';
import { LoginPage } from './pages/LoginPage';
import { RouteGuard } from './components/RouteGuard';
import { AppLayout } from './layouts/AppLayout';
import { InboxPage } from './pages/InboxPage';
import { UploadPage } from './pages/UploadPage';
import { QueuePage } from './pages/QueuePage';
import { ReviewPage } from './pages/ReviewPage';
import { LedgerPage } from './pages/LedgerPage';
import { AuditPage } from './pages/AuditPage';

export function App() {
  return (
    <ThemeProvider>
      <BrowserRouter>
        <Routes>
          {/* Surface 1: Cinematic Motion Landing (Public) */}
          <Route path="/" element={<LandingPage />} />

          {/* Public Login Route */}
          <Route path="/app/login" element={<LoginPage />} />

          {/* Surface 2: Swiss Editorial App (JWT Protected) */}
          <Route path="/app" element={<RouteGuard />}>
            <Route element={<AppLayout />}>
              <Route index element={<Navigate to="/app/inbox" replace />} />
              <Route path="inbox" element={<InboxPage />} />
              <Route path="upload" element={<UploadPage />} />
              <Route path="queue" element={<QueuePage />} />
              <Route path="queue/:id" element={<ReviewPage />} />
              <Route path="ledger" element={<LedgerPage />} />
              <Route path="audit" element={<AuditPage />} />
            </Route>
          </Route>

          {/* Backward-compatible redirects */}
          <Route path="/dashboard" element={<Navigate to="/app/inbox" replace />} />
          <Route path="/upload" element={<Navigate to="/app/upload" replace />} />
          <Route path="/approvals" element={<Navigate to="/app/queue" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}

export default App;
