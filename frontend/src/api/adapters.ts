import type { Task } from "@/types/task"

import type {
  ApiTask
} from "@/api/tasks";


export function apiTaskToTask(
  task: ApiTask
): Task {

  return {

    id:
      task.id,

    title:
      task.title,

    description:
      task.description ?? "",

    projectId:
      task.project_id,

    status:
      task.status === "in_progress"
        ? "in-progress"
        : task.status,

    priority:
      task.priority,

    due:
      task.due_date?.slice(0, 10) ?? "",

  };
}
