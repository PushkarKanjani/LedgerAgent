import { ApprovalRequest, InvoiceUploadResponse, SystemHealthReport } from '../types';

// Relative /api/v1 (routed via Vite proxy to 127.0.0.1:8000) or explicit env var
const API_BASE = import.meta.env.VITE_API_BASE_URL || '/api/v1';

export interface UserProfile {
  id: string;
  email: string;
  role: 'uploader' | 'reviewer' | 'admin';
  created_at: string;
}

export interface InboxStats {
  total_processed: number;
  pending_hitl: number;
  posted_volume: number;
  stp_rate: string;
}

export function getAuthToken(): string | null {
  return localStorage.getItem('ledger_auth_token');
}

export function setAuthSession(token: string, refreshToken: string, user: UserProfile) {
  localStorage.setItem('ledger_auth_token', token);
  localStorage.setItem('ledger_refresh_token', refreshToken);
  localStorage.setItem('ledger_user_profile', JSON.stringify(user));
}

export function getCachedUserProfile(): UserProfile | null {
  const data = localStorage.getItem('ledger_user_profile');
  if (!data) return null;
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
}

export function clearAuthSession() {
  localStorage.removeItem('ledger_auth_token');
  localStorage.removeItem('ledger_refresh_token');
  localStorage.removeItem('ledger_user_profile');
}

/**
 * Common fetch wrapper with automatic JWT Bearer injection & 401 interception.
 */
export async function authenticatedFetch(url: string, options: RequestInit = {}): Promise<Response> {
  const token = getAuthToken();
  const headers = new Headers(options.headers || {});

  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const response = await fetch(url, { ...options, headers });

  if (response.status === 401 && !url.includes('/auth/login')) {
    console.warn('[Auth Interceptor] 401 Unauthorized encountered. Redirecting to login.');
    clearAuthSession();
    if (!window.location.pathname.includes('/app/login')) {
      window.location.href = '/app/login';
    }
  }

  return response;
}


// =============================================================================
// API METHODS (All Authenticated)
// =============================================================================

export async function loginUser(email: string, password: string): Promise<{ access_token: string; refresh_token: string; user: UserProfile }> {
  const response = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    let detailMsg = errorBody;
    try {
      const parsed = JSON.parse(errorBody);
      detailMsg = parsed.detail || errorBody;
    } catch {}
    throw new Error(detailMsg || 'Invalid email or password');
  }

  const data = await response.json();
  setAuthSession(data.access_token, data.refresh_token, data.user);
  return data;
}

export async function fetchHealthReport(): Promise<SystemHealthReport | null> {
  try {
    const response = await fetch(`${API_BASE}/health`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
    if (!response.ok) return null;
    return await response.json();
  } catch {
    try {
      const rootResp = await fetch('/health');
      if (rootResp.ok) return await rootResp.json();
    } catch {}
    return null;
  }
}

export async function fetchInvoices(): Promise<any[]> {
  try {
    const response = await authenticatedFetch(`${API_BASE}/invoices`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
    if (!response.ok) return [];
    return await response.json();
  } catch {
    return [];
  }
}

export async function fetchInboxStats(): Promise<InboxStats> {
  try {
    const response = await authenticatedFetch(`${API_BASE}/invoices/stats`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
    if (!response.ok) {
      return { total_processed: 0, pending_hitl: 0, posted_volume: 0, stp_rate: '0.0%' };
    }
    return await response.json();
  } catch {
    return { total_processed: 0, pending_hitl: 0, posted_volume: 0, stp_rate: '0.0%' };
  }
}

export async function uploadInvoicePdf(file: File): Promise<InvoiceUploadResponse> {
  const formData = new FormData();
  formData.append('file', file);

  console.log(`[API] Uploading invoice to ${API_BASE}/invoices/upload:`, file.name);

  let response: Response;
  try {
    response = await authenticatedFetch(`${API_BASE}/invoices/upload`, {
      method: 'POST',
      body: formData,
    });
  } catch (networkError: any) {
    throw new Error(
      `Network Error: Could not connect to backend at ${API_BASE}. Details: ${networkError.message}`
    );
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => '');
    let detailMsg = errorBody;
    try {
      const parsed = JSON.parse(errorBody);
      detailMsg = parsed.detail || errorBody;
    } catch {}
    throw new Error(`HTTP ${response.status}: ${detailMsg || 'Upload rejected by server'}`);
  }

  return await response.json();
}

export async function fetchPendingApprovals(): Promise<ApprovalRequest[]> {
  try {
    const response = await authenticatedFetch(`${API_BASE}/approvals/pending`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });

    if (!response.ok) return [];
    return await response.json();
  } catch {
    return [];
  }
}

export async function fetchGLEntries(): Promise<any[]> {
  try {
    const response = await authenticatedFetch(`${API_BASE}/gl-entries`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
    if (!response.ok) return [];
    return await response.json();
  } catch {
    return [];
  }
}

export async function fetchAuditLogs(): Promise<any[]> {
  try {
    const response = await authenticatedFetch(`${API_BASE}/audit-logs`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' },
    });
    if (!response.ok) return [];
    return await response.json();
  } catch {
    return [];
  }
}

export async function submitHumanDecision(
  invoiceId: string,
  decision: 'APPROVED' | 'REJECTED' | 'CORRECTED_AND_APPROVED',
  reviewerNotes?: string
): Promise<any> {
  const payload = {
    decision: decision,
    reviewer_user_id: getCachedUserProfile()?.email || 'reviewer@ledgeragent.dev',
    reviewer_notes: reviewerNotes || 'Approved via LedgerAgent React HITL Dashboard',
    corrected_payload: null,
  };

  const response = await authenticatedFetch(`${API_BASE}/approvals/${encodeURIComponent(invoiceId)}/decide`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorBody = await response.text().catch(() => '');
    let detailMsg = errorBody;
    try {
      const parsed = JSON.parse(errorBody);
      detailMsg = parsed.detail || errorBody;
    } catch {}
    throw new Error(`HTTP ${response.status}: ${detailMsg || 'Decision rejected by server'}`);
  }

  return await response.json();
}
