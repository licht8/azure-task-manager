import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useWorkspace } from "@/data/store";

export function DeleteProjectDialog({
  open,
  onOpenChange,
  project,
  onDeleted,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  project?: {
    id: number;
    name: string;
  } | null;
  onDeleted?: (projectId: number) => void;
}) {
  const { deleteProject } = useWorkspace();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

	async function handleDelete() {
	  if (!project) return;

	  setLoading(true);
	  setError("");

	  try {
		await deleteProject(project.id);

		onDeleted?.(project.id);
		onOpenChange(false);
	  } catch (error) {
		console.error("Failed to delete project:", error);

		setError(
		  error instanceof Error
			? error.message
			: "Failed to delete project.",
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
            Project
          </p>

          <DialogTitle>Delete Project</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Are you sure you want to delete{" "}
            <span className="font-medium text-foreground">
              "{project?.name}"
            </span>
            ?
          </p>

          <div className="rounded-lg bg-muted/50 px-3 py-2.5 text-sm text-muted-foreground">
            The project will be deleted, but all tasks inside it will remain
            in your workspace without a project.
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
              type="button"
              onClick={handleDelete}
              disabled={loading || !project}
              className="rounded-lg bg-destructive px-4 py-2 text-sm font-medium text-destructive-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {loading ? "Deleting..." : "Delete project"}
            </button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}