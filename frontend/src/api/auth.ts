import { apiFetch } from "@/api/client";

export type ApiUser = {
  id: number;
  username: string;
  email: string;
  avatar: string;
  created_at: string;
};

export function isAuthenticated(): boolean {
  return Boolean(
    localStorage.getItem("access_token")
  );
}

export function logout(): void {
  localStorage.removeItem("access_token");
}

export async function getCurrentUser(): Promise<ApiUser> {
  const response = await apiFetch("/auth/me");

  if (!response.ok) {
    throw new Error("Failed to load current user");
  }

  return response.json();
}

export async function updateProfileRequest(
  username: string,
  avatar: string,
): Promise<ApiUser> {
  const response = await apiFetch("/auth/profile", {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      username,
      avatar,
    }),
  });

  if (!response.ok) {
    const data = await response.json().catch(() => null);

    throw new Error(
      data?.detail ?? "Failed to update profile",
    );
  }

  return response.json();
}

export async function changePassword(
  currentPassword: string,
  newPassword: string,
): Promise<void> {
  const response = await apiFetch(
    "/auth/change-password",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        current_password: currentPassword,
        new_password: newPassword,
      }),
    },
  );

  if (!response.ok) {
    const data = await response.json().catch(() => null);

    throw new Error(
      data?.detail ?? "Failed to change password",
    );
  }
}