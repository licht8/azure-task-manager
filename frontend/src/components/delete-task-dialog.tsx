import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useWorkspace } from "@/data/store";
import type { Task } from "@/types/task";

export function DeleteTaskDialog({
  open,
  onOpenChange,
  task,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  task?: Task | null;
}) {
  const { deleteTask } = useWorkspace();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleDelete() {
    if (!task) return;

    setLoading(true);
    setError("");

    try {
      await deleteTask(task.id);

      onOpenChange(false);
    } catch (error) {
      console.error("Failed to delete task:", error);

      setError(
        error instanceof Error
          ? error.message
          : "Failed to delete task.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(value) => {
        if (!loading) {
          onOpenChange(value);
        }
      }}
    >
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Task
          </p>

          <DialogTitle>
            Delete Task
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="rounded-lg bg-destructive/10 px-4 py-3">
            <p className="text-sm font-medium text-destructive">
              Are you sure you want to delete this task?
            </p>

            {task ? (
              <p className="mt-1 text-sm text-muted-foreground">
                "{task.title}"
              </p>
            ) : null}
          </div>

          <p className="text-sm text-muted-foreground">
            This action cannot be undone.
          </p>

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
              type="button"
              onClick={handleDelete}
              disabled={loading || !task}
              className="rounded-lg bg-destructive px-4 py-2 text-sm font-medium text-destructive-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading ? "Deleting..." : "Delete task"}
            </button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}