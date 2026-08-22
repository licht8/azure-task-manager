import { redirect } from "@tanstack/react-router";

export function requireAuth() {
  if (typeof window === "undefined") {
    return;
  }

  const token = localStorage.getItem("access_token");

  if (!token) {
    throw redirect({
      to: "/login",
    });
  }
}