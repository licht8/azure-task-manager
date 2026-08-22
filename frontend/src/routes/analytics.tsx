import { requireAuth } from "@/lib/require-auth";
import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { AppShell } from "@/components/app-shell";
import { getAnalytics, type ApiAnalytics } from "@/api/analytics";

export const Route = createFileRoute("/analytics")({
  beforeLoad: () => {
    requireAuth();
  },

  head: () => ({
    meta: [
      { title: "Analytics — Tasky Workspace" },
      {
        name: "description",
        content:
          "Understand your task activity, priorities and productivity trends.",
      },
      {
        property: "og:title",
        content: "Analytics — Tasky Workspace",
      },
      {
        property: "og:description",
        content:
          "Understand your task activity, priorities and productivity trends.",
      },
    ],
  }),

  component: AnalyticsPage,
});

function Metric({
  label,
  value,
  hint,
}: {
  label: string;
  value: number;
  hint: string;
}) {
  return (
    <div className="surface p-5">
      <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
        {label}
      </p>

      <p className="mt-2 text-3xl font-semibold">
        {value}
      </p>

      <p className="mt-1 text-xs text-muted-foreground">
        {hint}
      </p>
    </div>
  );
}

function Bar({
  label,
  value,
  total,
}: {
  label: string;
  value: number;
  total: number;
}) {
  const percentage =
    total > 0 ? (value / total) * 100 : 0;

  return (
    <div>
      <div className="flex justify-between text-sm">
        <span className="text-muted-foreground">
          {label}
        </span>

        <span className="font-medium">
          {value}
        </span>
      </div>

      <div className="mt-1.5 h-2 rounded-full bg-muted">
        <div
          className="h-2 rounded-full bg-primary transition-all"
          style={{
            width: `${percentage}%`,
          }}
        />
      </div>
    </div>
  );
}

function formatActivityDate(date: string) {
  return new Date(date).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function activityIcon(action: string) {
  switch (action) {
    case "created":
      return "＋";

    case "updated":
      return "✎";

    case "deleted":
      return "×";

    default:
      return "•";
  }
}

function AnalyticsPage() {
  const [data, setData] = useState<ApiAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadAnalytics() {
      try {
        setLoading(true);
        setError(null);

        const analytics = await getAnalytics();

        setData(analytics);
      } catch (error) {
        console.error("Failed to load analytics:", error);

        setError(
          error instanceof Error
            ? error.message
            : "Failed to load analytics",
        );
      } finally {
        setLoading(false);
      }
    }

    loadAnalytics();
  }, []);

  if (loading) {
    return (
      <AppShell
        breadcrumb={["Workspace", "Analytics"]}
        title="Analytics"
        subtitle="Understand your task activity and productivity."
      >
        <div className="surface p-8 text-center text-sm text-muted-foreground">
          Loading analytics...
        </div>
      </AppShell>
    );
  }

  if (error || !data) {
    return (
      <AppShell
        breadcrumb={["Workspace", "Analytics"]}
        title="Analytics"
        subtitle="Understand your task activity and productivity."
      >
        <div className="surface p-8 text-center">
          <p className="text-sm font-medium text-destructive">
            Failed to load analytics
          </p>

          <p className="mt-1 text-xs text-muted-foreground">
            {error ?? "No analytics data available."}
          </p>
        </div>
      </AppShell>
    );
  }

  const stats = data.statistics;

  return (
    <AppShell
      breadcrumb={["Workspace", "Analytics"]}
      title="Analytics"
      subtitle="Understand your task activity and productivity."
    >
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Metric
          label="Total tasks"
          value={stats.total}
          hint="All active tasks"
        />

        <Metric
          label="Completed"
          value={stats.completed}
          hint="Finished tasks"
        />

        <Metric
          label="In progress"
          value={stats.in_progress}
          hint="Currently working on"
        />

        <Metric
          label="Overdue"
          value={stats.overdue}
          hint="Need your attention"
        />
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <section className="surface p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Status
          </p>

          <h2 className="mt-1 text-base font-semibold">
            Task status
          </h2>

          <div className="mt-5 space-y-4">
            <Bar
              label="Pending"
              value={stats.pending}
              total={stats.total}
            />

            <Bar
              label="In Progress"
              value={stats.in_progress}
              total={stats.total}
            />

            <Bar
              label="Completed"
              value={stats.completed}
              total={stats.total}
            />
          </div>
        </section>

        <section className="surface p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Priority
          </p>

          <h2 className="mt-1 text-base font-semibold">
            Task priority
          </h2>

          <div className="mt-5 space-y-4">
            <Bar
              label="Low"
              value={stats.low_priority}
              total={stats.total}
            />

            <Bar
              label="Medium"
              value={stats.medium_priority}
              total={stats.total}
            />

            <Bar
              label="High"
              value={stats.high_priority}
              total={stats.total}
            />
          </div>
        </section>
      </div>

      <section className="surface mt-6 overflow-hidden">
        <header className="border-b border-border px-6 py-5">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Activity
          </p>

          <h2 className="mt-1 text-base font-semibold">
            Recent activity
          </h2>

          <p className="text-sm text-muted-foreground">
            Your latest task changes
          </p>
        </header>

        <ul className="divide-y divide-border">
          {data.activity.map((activity) => (
            <li
              key={activity.id}
              className="flex items-center gap-4 px-6 py-4"
            >
              <span className="grid size-8 shrink-0 place-items-center rounded-full bg-primary/10 text-sm text-primary">
                {activityIcon(activity.action)}
              </span>

              <div className="min-w-0">
                <p className="truncate text-sm font-medium">
                  {activity.description}
                </p>

                <p className="text-xs text-muted-foreground">
                  {formatActivityDate(activity.created_at)}
                </p>
              </div>
            </li>
          ))}

          {data.activity.length === 0 ? (
            <li className="px-6 py-10 text-center text-sm text-muted-foreground">
              No activity yet.
            </li>
          ) : null}
        </ul>
      </section>
    </AppShell>
  );
}