import { apiFetch } from "@/api/client";

export type ApiAnalyticsStatistics = {
  total: number;
  pending: number;
  in_progress: number;
  completed: number;
  overdue: number;
  low_priority: number;
  medium_priority: number;
  high_priority: number;
};

export type ApiActivity = {
  id: number;
  task_id: number;
  action: string;
  description: string;
  created_at: string;
};

export type ApiAnalytics = {
  statistics: ApiAnalyticsStatistics;
  activity: ApiActivity[];
};

export async function getAnalytics(): Promise<ApiAnalytics> {
  const response = await apiFetch("/analytics");

  if (!response.ok) {
    const data = await response.json().catch(() => null);

    throw new Error(
      data?.detail ?? "Failed to load analytics",
    );
  }

  return response.json();
}