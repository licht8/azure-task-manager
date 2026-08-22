import { apiFetch } from "@/api/client";

export type ApiProject = {
  id: number;
  name: string;
};

export async function getProjects() {
  const response = await apiFetch("/projects");

  if (!response.ok) {
    throw new Error("Failed to load projects");
  }

  return response.json() as Promise<ApiProject[]>;
}

export async function createProjectRequest(name: string) {
  const response = await apiFetch("/projects", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name }),
  });

  if (!response.ok) {
    throw new Error("Failed to create project");
  }

  return response.json() as Promise<ApiProject>;
}