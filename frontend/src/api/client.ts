const API_URL = import.meta.env.VITE_API_URL;

export async function apiFetch(
  endpoint: string,
  options: RequestInit = {},
) {
  const token = localStorage.getItem("access_token");

  const headers = {
    ...(options.headers || {}),
    ...(token
      ? {
          Authorization: `Bearer ${token}`,
        }
      : {}),
  };

  let response: Response;

  try {
    response = await fetch(`${API_URL}${endpoint}`, {
      ...options,
      headers,
    });
  } catch {
    throw new Error(
      "Unable to connect to the server. Please check your connection and try again.",
    );
  }

  // Authentication endpoints must handle their own 401 responses.
  const isAuthRequest =
    endpoint === "/auth/login" ||
    endpoint === "/auth/register";

  if (response.status === 401 && !isAuthRequest) {
    localStorage.removeItem("access_token");

    window.location.href = "/login";

    throw new Error("Your session has expired. Please log in again.");
  }

  return response;
}