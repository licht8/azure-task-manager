import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useWorkspace, type TaskInput } from "@/data/store";
import type { Task, TaskPriority, TaskStatus } from "@/types/task"

const inputClass =
  "mt-1.5 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring/40";

const empty: TaskInput = {
  title: "",
  description: "",
  projectId: null,
  status: "pending",
  priority: "medium",
  due: "",
};

export function TaskDialog({
  open,
  onOpenChange,
  task,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  task?: Task | null;
}) {
  const { projects, createTask, updateTask } = useWorkspace();

  const [form, setForm] = useState<TaskInput>(empty);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open) return;

    setError("");
    setForm(
      task
        ? {
            title: task.title,
            description: task.description,
            projectId: task.projectId ?? null,
            status: task.status,
            priority: task.priority,
            due: task.due,
          }
        : empty,
    );
  }, [open, task]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();

    if (!form.title.trim()) {
      setError("Title is required.");
      return;
    }

    setLoading(true);
    setError("");

    try {
      if (task) {
        await updateTask(task.id, form);
      } else {
        await createTask(form);
      }

      onOpenChange(false);
    } catch (error) {
      console.error("Failed to save task:", error);

      setError(
        error instanceof Error
          ? error.message
          : "Failed to save task.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Task
          </p>

          <DialogTitle>
            {task ? "Edit Task" : "New Task"}
          </DialogTitle>
        </DialogHeader>

        <form className="space-y-4" onSubmit={submit}>
          <div>
            <label
              className="text-sm font-medium"
              htmlFor="task-title"
            >
              Title
            </label>

            <input
              id="task-title"
              className={inputClass}
              value={form.title}
              onChange={(e) =>
                setForm({
                  ...form,
                  title: e.target.value,
                })
              }
              placeholder="Task title"
              disabled={loading}
            />
          </div>

          <div>
            <label
              className="text-sm font-medium"
              htmlFor="task-desc"
            >
              Description
            </label>

            <textarea
              id="task-desc"
              rows={3}
              className={inputClass}
              value={form.description}
              onChange={(e) =>
                setForm({
                  ...form,
                  description: e.target.value,
                })
              }
              placeholder="What needs to be done?"
              disabled={loading}
            />
          </div>

          <div>
            <label
              className="text-sm font-medium"
              htmlFor="task-project"
            >
              Project
            </label>

            <select
              id="task-project"
              className={inputClass}
              value={form.projectId ?? ""}
              onChange={(e) =>
                setForm({
                  ...form,
                  projectId: e.target.value
                    ? Number(e.target.value)
                    : null,
                })
              }
              disabled={loading}
            >
              <option value="">No project</option>

              {projects.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label
                className="text-sm font-medium"
                htmlFor="task-status"
              >
                Status
              </label>

              <select
                id="task-status"
                className={inputClass}
                value={form.status}
                onChange={(e) =>
                  setForm({
                    ...form,
                    status: e.target.value as TaskStatus,
                  })
                }
                disabled={loading}
              >
                <option value="pending">Pending</option>
                <option value="in-progress">In progress</option>
                <option value="completed">Completed</option>
              </select>
            </div>

            <div>
              <label
                className="text-sm font-medium"
                htmlFor="task-priority"
              >
                Priority
              </label>

              <select
                id="task-priority"
                className={inputClass}
                value={form.priority}
                onChange={(e) =>
                  setForm({
                    ...form,
                    priority: e.target.value as TaskPriority,
                  })
                }
                disabled={loading}
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
              </select>
            </div>
          </div>

          <div>
            <label
              className="text-sm font-medium"
              htmlFor="task-due"
            >
              Due date
            </label>

            <input
              id="task-due"
              type="date"
              className={inputClass}
              value={form.due}
              onChange={(e) =>
                setForm({
                  ...form,
                  due: e.target.value,
                })
              }
              disabled={loading}
            />
          </div>

          {error ? (
            <div className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">
              {error}
            </div>
          ) : null}

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={() => onOpenChange(false)}
              disabled={loading}
              className="rounded-lg border border-border px-4 py-2 text-sm transition-colors hover:bg-accent disabled:cursor-not-allowed disabled:opacity-50"
            >
              Cancel
            </button>

            <button
              type="submit"
              disabled={loading}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading
                ? task
                  ? "Saving..."
                  : "Creating..."
                : task
                  ? "Save changes"
                  : "Create task"}
            </button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}