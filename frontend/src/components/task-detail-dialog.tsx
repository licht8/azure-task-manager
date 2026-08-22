import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useWorkspace } from "@/data/store";
import type { Task } from "@/types/task"

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-border py-2.5 last:border-b-0">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="text-sm font-medium capitalize">{value}</span>
    </div>
  );
}

export function TaskDetailDialog({
  task,
  onOpenChange,
}: {
  task: Task | null;
  onOpenChange: (v: boolean) => void;
}) {
  const { projectName } = useWorkspace();

  return (
    <Dialog open={!!task} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        {task ? (
          <>
            <DialogHeader>
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Task</p>
              <DialogTitle>{task.title}</DialogTitle>
            </DialogHeader>
            <p className="text-sm text-muted-foreground">{task.description || "No description"}</p>
            <div className="mt-2">
              <Row label="Project" value={projectName(task.projectId)} />
              <Row label="Status" value={task.status.replace("-", " ")} />
              <Row label="Priority" value={task.priority} />
              <Row label="Due date" value={task.due || "—"} />
            </div>
          </>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
