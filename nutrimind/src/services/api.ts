// API wrapper for backend calls with proper auth handling

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "";

interface RequestConfig extends RequestInit {
  headers?: Record<string, string>;
}

// Token storage - centralized for maintainability
// Note: httpOnly cookies would be more secure, but require backend changes
export const tokenStorage = {
  get: (): string | null => {
    if (typeof window === "undefined") return null;
    return localStorage.getItem("nutrimind_token");
  },
  set: (token: string) => {
    if (typeof window === "undefined") return;
    localStorage.setItem("nutrimind_token", token);
  },
  remove: () => {
    if (typeof window === "undefined") return;
    localStorage.removeItem("nutrimind_token");
  },
};

function getAuthHeaders(): Record<string, string> {
  const token = tokenStorage.get();
  if (!token) return {};
  return { Authorization: `Bearer ${token}` };
}

export async function apiClient<T>(
  endpoint: string,
  options: RequestConfig = {}
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  const authHeaders = getAuthHeaders();

  const config: RequestInit = {
    headers: {
      "Content-Type": "application/json",
      ...authHeaders,
      ...options.headers,
    },
    signal: options.signal,
    method: options.method,
    body: options.body,
  };

  const response = await fetch(url, config);

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.detail || `API Error: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

export const api = {
  get: <T>(endpoint: string, config?: Omit<RequestConfig, 'method' | 'body'>) =>
    apiClient<T>(endpoint, { ...config, method: "GET" }),
  post: <T>(endpoint: string, data?: unknown, config?: Omit<RequestConfig, 'method' | 'body'>) =>
    apiClient<T>(endpoint, { ...config, method: "POST", body: JSON.stringify(data) }),
  put: <T>(endpoint: string, data?: unknown, config?: Omit<RequestConfig, 'method' | 'body'>) =>
    apiClient<T>(endpoint, { ...config, method: "PUT", body: JSON.stringify(data) }),
  delete: <T>(endpoint: string, config?: Omit<RequestConfig, 'method' | 'body'>) =>
    apiClient<T>(endpoint, { ...config, method: "DELETE" }),
};
