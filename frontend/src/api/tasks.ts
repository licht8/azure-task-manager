import { apiFetch } from "@/api/client";

export type ApiTask = {
  id: number;
  title: string;
  description: string | null;
  project_id: number | null;
  status: "pending" | "in_progress" | "completed";
  priority: "low" | "medium" | "high";
  due_date: string | null;
};

export type CreateTaskData = {
  title: string;
  description?: string;
  project_id?: number | null;
  status: "pending" | "in_progress" | "completed";
  priority: "low" | "medium" | "high";
  due_date?: string | null;
};

export type UpdateTaskData = Partial<CreateTaskData>;

export async function getTasks(): Promise<ApiTask[]> {
  const response = await apiFetch("/tasks");

  if (!response.ok) {
    throw new Error("Failed to load tasks");
  }

  return response.json();
}

export async function createTaskRequest(
  data: CreateTaskData
): Promise<ApiTask> {
  const response = await apiFetch("/tasks", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error("Failed to create task");
  }

  return response.json();
}

export async function updateTaskRequest(
  id: number,
  data: UpdateTaskData
): Promise<ApiTask> {
  const response = await apiFetch(`/tasks/${id}`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error("Failed to update task");
  }

  return response.json();
}

export async function deleteTaskRequest(
  id: number
): Promise<void> {
  const response = await apiFetch(`/tasks/${id}`, {
    method: "DELETE",
  });

  if (!response.ok) {
    throw new Error("Failed to delete task");
  }
}
