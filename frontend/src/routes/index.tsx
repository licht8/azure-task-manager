import { requireAuth } from "@/lib/require-auth";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Hash, Clock, ArrowUpRight, Check, Plus, Pencil, Trash2, X } from "lucide-react";
import { useMemo, useState } from "react";
import { AppShell } from "@/components/app-shell";
import { TaskDialog } from "@/components/task-dialog";
import type { Task } from "@/types/task"
import { useWorkspace } from "@/data/store";

export const Route = createFileRoute("/")({
  beforeLoad: () => {
    requireAuth();
  },
  head: () => ({
    meta: [
      { title: "Dashboard — Tasky Workspace" },
      { name: "description", content: "Track your tasks, progress and productivity in one calm pastel workspace." },
      { property: "og:title", content: "Dashboard — Tasky Workspace" },
      { property: "og:description", content: "Track your tasks, progress and productivity in one calm pastel workspace." },
    ],
  }),
  component: Dashboard,
});

const statusStyles: Record<string, string> = {
  pending: "bg-secondary text-secondary-foreground",
  "in-progress": "bg-primary/15 text-primary",
  completed: "bg-success/15 text-success",
};

const priorityStyles: Record<string, string> = {
  low: "text-muted-foreground",
  medium: "text-warning",
  high: "text-destructive",
};

function StatCard({ icon, label, value }: { icon: React.ReactNode; label: string; value: number }) {
  return (
    <div className="surface flex items-center gap-4 p-5">
      <div className="grid size-10 place-items-center rounded-xl bg-primary/10 text-primary">{icon}</div>
      <div>
        <p className="text-xs uppercase tracking-wide text-muted-foreground">{label}</p>
        <p className="text-2xl font-semibold">{value}</p>
      </div>
    </div>
  );
}

function Dashboard() {
  const { project } = Route.useSearch();
  const navigate = useNavigate();
  const { tasks, deleteTask, projectName } = useWorkspace();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Task | null>(null);

  const visible = useMemo(
    () => (project ? tasks.filter((t) => t.projectId === project) : tasks),
    [tasks, project],
  );

  const stats = {
    total: visible.length,
    pending: visible.filter((t) => t.status === "pending").length,
    inProgress: visible.filter((t) => t.status === "in-progress").length,
    completed: visible.filter((t) => t.status === "completed").length,
  };

  return (
    <AppShell
      breadcrumb={["Workspace", "Dashboard"]}
      title="My Tasks"
      subtitle="Manage your tasks and stay productive."
      actions={
        <button
          onClick={() => {
            setEditing(null);
            setDialogOpen(true);
          }}
          className="flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
        >
          <Plus className="size-4" /> Create new task
        </button>
      }
    >
      {project ? (
        <div className="mb-5 flex items-center gap-2">
          <span className="inline-flex items-center gap-2 rounded-full bg-primary/10 px-3 py-1.5 text-sm text-primary">
            Project: {projectName(project)}
            <button onClick={() => navigate({ to: "/", search: { project: undefined } })} aria-label="Clear project filter">
              <X className="size-3.5" />
            </button>
          </span>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon={<Hash className="size-5" />} label="Total Tasks" value={stats.total} />
        <StatCard icon={<Clock className="size-5" />} label="Pending" value={stats.pending} />
        <StatCard icon={<ArrowUpRight className="size-5" />} label="In Progress" value={stats.inProgress} />
        <StatCard icon={<Check className="size-5" />} label="Completed" value={stats.completed} />
      </div>

      <section className="surface mt-6 overflow-hidden">
        <header className="border-b border-border px-6 py-5">
          <h2 className="text-base font-semibold">Tasks</h2>
          <p className="text-sm text-muted-foreground">Your personal task list</p>
        </header>
        <ul className="divide-y divide-border">
          {visible.map((task) => (
            <li key={task.id} className="flex items-center gap-4 px-6 py-4">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{task.title}</p>
                <p className="truncate text-xs text-muted-foreground">{task.description}</p>
              </div>
              <span className="hidden text-xs text-muted-foreground sm:block">{projectName(task.projectId)}</span>
              <span className={`text-xs font-medium ${priorityStyles[task.priority]}`}>{task.priority}</span>
              <span className={`rounded-full px-3 py-1 text-xs font-medium ${statusStyles[task.status]}`}>
                {task.status.replace("-", " ")}
              </span>
              <div className="flex items-center gap-1">
                <button
                  aria-label={`Edit ${task.title}`}
                  onClick={() => {
                    setEditing(task);
                    setDialogOpen(true);
                  }}
                  className="grid size-8 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                >
                  <Pencil className="size-4" />
                </button>
                <button
                  aria-label={`Delete ${task.title}`}
                  onClick={() => deleteTask(task.id)}
                  className="grid size-8 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                >
                  <Trash2 className="size-4" />
                </button>
              </div>
            </li>
          ))}
          {visible.length === 0 ? (
            <li className="px-6 py-10 text-center text-sm text-muted-foreground">No tasks here yet.</li>
          ) : null}
        </ul>
      </section>

      <TaskDialog open={dialogOpen} onOpenChange={setDialogOpen} task={editing} />
    </AppShell>
  );
}
