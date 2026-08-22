import { requireAuth } from "@/lib/require-auth";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell } from "@/components/app-shell";
import { TaskDetailDialog } from "@/components/task-detail-dialog";
import { useWorkspace } from "@/data/store";
import type { Task } from "@/types/task"

export const Route = createFileRoute("/calendar")({
  beforeLoad: () => {
    requireAuth();
  },
  head: () => ({
    meta: [
      { title: "Calendar — Tasky Workspace" },
      {
        name: "description",
        content: "See your tasks laid out day by day in a clean monthly calendar.",
      },
      {
        property: "og:title",
        content: "Calendar — Tasky Workspace",
      },
      {
        property: "og:description",
        content: "See your tasks laid out day by day in a clean monthly calendar.",
      },
    ],
  }),
  component: CalendarPage,
});

const weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const dotByStatus: Record<string, string> = {
  pending: "bg-warning",
  "in-progress": "bg-primary",
  completed: "bg-success",
};

function CalendarPage() {
  const { tasks, projectName } = useWorkspace();

  const [cursor, setCursor] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });

  const [selectedTask, setSelectedTask] =
    useState<Task | null>(null);

  const year = cursor.getFullYear();
  const month = cursor.getMonth();

  const first = new Date(year, month, 1);

  const startOffset =
    (first.getDay() + 6) % 7;

  const daysInMonth =
    new Date(year, month + 1, 0).getDate();

  const cells: (number | null)[] = [
    ...Array.from(
      { length: startOffset },
      () => null
    ),
    ...Array.from(
      { length: daysInMonth },
      (_, i) => i + 1
    ),
  ];

  while (cells.length % 7 !== 0) {
    cells.push(null);
  }

  const monthLabel =
    first.toLocaleDateString("en-US", {
      month: "long",
      year: "numeric",
    });

  function tasksFor(day: number) {
    const iso =
      `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;

    return tasks.filter(
      (task) => task.due === iso
    );
  }

  return (
    <AppShell
      breadcrumb={["Workspace", "Calendar"]}
      title="Calendar"
      subtitle="Your tasks organised across the month."
    >
      <div className="surface overflow-hidden">
        <header className="flex items-center justify-between border-b border-border px-6 py-4">
          <h2 className="text-base font-semibold">
            {monthLabel}
          </h2>

          <div className="flex gap-2">
            <button
              onClick={() =>
                setCursor(
                  new Date(year, month - 1, 1)
                )
              }
              className="rounded-lg border border-border px-3 py-1.5 text-sm transition-colors hover:bg-accent"
            >
              Prev
            </button>

            <button
              onClick={() =>
                setCursor(
                  new Date(year, month + 1, 1)
                )
              }
              className="rounded-lg border border-border px-3 py-1.5 text-sm transition-colors hover:bg-accent"
            >
              Next
            </button>
          </div>
        </header>

        <div className="grid grid-cols-7 border-b border-border bg-muted/50">
          {weekDays.map((day) => (
            <div
              key={day}
              className="px-3 py-2 text-center text-xs font-medium text-muted-foreground"
            >
              {day}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-7">
          {cells.map((day, index) => (
            <div
              key={index}
              className="min-h-28 border-b border-r border-border p-2 last:border-r-0 [&:nth-child(7n)]:border-r-0"
            >
              {day ? (
                <>
                  <span className="text-xs font-medium text-muted-foreground">
                    {day}
                  </span>

                  <div className="mt-1 space-y-1">
                    {tasksFor(day).map((task) => (
                      <button
                        key={task.id}
                        type="button"
                        onClick={() =>
                          setSelectedTask(task)
                        }
                        className="flex w-full items-center gap-1.5 rounded-md bg-primary/10 px-2 py-1 text-left text-[11px] text-foreground transition-colors hover:bg-primary/20"
                        title={
                          task.projectId
                            ? projectName(task.projectId)
                            : "No project"
                        }
                      >
                        <span
                          className={`size-1.5 shrink-0 rounded-full ${
                            dotByStatus[task.status]
                          }`}
                        />

                        <span className="min-w-0 flex-1 truncate">
                          {task.title}
                        </span>
                      </button>
                    ))}
                  </div>
                </>
              ) : null}
            </div>
          ))}
        </div>
      </div>

      <TaskDetailDialog
        task={selectedTask}
        onOpenChange={(open) => {
          if (!open) {
            setSelectedTask(null);
          }
        }}
      />
    </AppShell>
  );
}