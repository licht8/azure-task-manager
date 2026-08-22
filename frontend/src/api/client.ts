const API_URL = import.meta.env.VITE_API_URL;


export async function apiFetch(
  endpoint: string,
  options: RequestInit = {}
) {

  const token =
    localStorage.getItem(
      "access_token"
    );


  const headers = {
    ...(options.headers || {}),

    ...(token
      ? {
          Authorization:
            `Bearer ${token}`,
        }
      : {}),
  };


  const response =
    await fetch(
      `${API_URL}${endpoint}`,
      {
        ...options,
        headers,
      }
    );


  if (
    response.status === 401
  ) {

    localStorage.removeItem(
      "access_token"
    );

    window.location.href =
      "/login";

    throw new Error(
      "Unauthorized"
    );
  }


  return response;
}
