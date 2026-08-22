import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useWorkspace } from "@/data/store";
import { cn } from "@/lib/utils";

export function ProjectDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const { tasks, createProject } = useWorkspace();
  const [name, setName] = useState("");
  const [selected, setSelected] = useState<number[]>([]);

  useEffect(() => {
    if (open) {
      setName("");
      setSelected([]);
    }
  }, [open]);

  const availableTasks = tasks.filter(
    (task) => task.projectId == null
  );

  const toggle = (id: number) => {
    setSelected((prev) =>
      prev.includes(id)
        ? prev.filter((x) => x !== id)
        : [...prev, id]
    );
  };

  const submit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!name.trim()) return;

    createProject(name.trim(), selected);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Project
          </p>

          <DialogTitle>New Project</DialogTitle>
        </DialogHeader>

        <form className="space-y-4" onSubmit={submit}>
          <div>
            <label
              className="text-sm font-medium"
              htmlFor="project-name"
            >
              Project name
            </label>

            <input
              id="project-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Website redesign"
              className="mt-1.5 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring/40"
            />
          </div>

          <div>
            <p className="text-sm font-medium">
              Attach existing tasks
            </p>

            <p className="text-xs text-muted-foreground">
              Selected tasks will be moved into this project
            </p>

            <div className="mt-2 max-h-56 space-y-1 overflow-y-auto rounded-lg border border-border p-2">
              {availableTasks.length === 0 ? (
                <p className="px-3 py-6 text-center text-sm text-muted-foreground">
                  All tasks are already assigned to projects.
                </p>
              ) : (
                availableTasks.map((t) => (
                  <button
                    type="button"
                    key={t.id}
                    onClick={() => toggle(t.id)}
                    className={cn(
                      "flex w-full items-center gap-3 rounded-md px-3 py-2 text-left text-sm transition-colors hover:bg-accent",
                      selected.includes(t.id) &&
                        "bg-primary/10",
                    )}
                  >
                    <span
                      className={cn(
                        "grid size-4 shrink-0 place-items-center rounded border border-border text-[10px]",
                        selected.includes(t.id) &&
                          "border-primary bg-primary text-primary-foreground",
                      )}
                    >
                      {selected.includes(t.id) ? "✓" : ""}
                    </span>

                    <span className="truncate">
                      {t.title}
                    </span>
                  </button>
                ))
              )}
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={() => onOpenChange(false)}
              className="rounded-lg border border-border px-4 py-2 text-sm transition-colors hover:bg-accent"
            >
              Cancel
            </button>

            <button
              type="submit"
              className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
            >
              Create project
            </button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}