// API wrapper for backend calls
// This will be implemented when the backend is ready

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "";

interface RequestConfig {
  headers?: Record<string, string>;
  signal?: AbortSignal;
}

export async function apiClient<T>(
  endpoint: string,
  options: RequestConfig = {}
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  const config: RequestInit = {
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
    signal: options.signal,
  };

  const response = await fetch(url, config);

  if (!response.ok) {
    throw new Error(`API Error: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

export const api = {
  get: <T>(endpoint: string, config?: RequestConfig) =>
    apiClient<T>(endpoint, { ...config, method: "GET" }),
  post: <T>(endpoint: string, data?: unknown, config?: RequestConfig) =>
    apiClient<T>(endpoint, { ...config, method: "POST", body: JSON.stringify(data) }),
  put: <T>(endpoint: string, data?: unknown, config?: RequestConfig) =>
    apiClient<T>(endpoint, { ...config, method: "PUT", body: JSON.stringify(data) }),
  delete: <T>(endpoint: string, config?: RequestConfig) =>
    apiClient<T>(endpoint, { ...config, method: "DELETE" }),
};