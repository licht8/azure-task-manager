import { Link, useRouterState, useNavigate } from "@tanstack/react-router";
import {
  LayoutDashboard,
  CalendarDays,
  BarChart3,
  Plus,
  User,
  Settings,
  LogOut,
  FolderKanban,
  Trash2,
} from "lucide-react";
import { useState, type ReactNode } from "react";
import { ProjectDialog } from "@/components/project-dialog";
import { DeleteProjectDialog } from "@/components/delete-project-dialog";
import { getAvatar } from "@/data/avatars";
import { useWorkspace } from "@/data/store";
import { cn } from "@/lib/utils";

const nav = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard },
  { to: "/calendar", label: "Calendar", icon: CalendarDays },
  { to: "/analytics", label: "Analytics", icon: BarChart3 },
] as const;

function SectionLabel({ children }: { children: ReactNode }) {
  return (
    <p className="px-3 pb-2 pt-4 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
      {children}
    </p>
  );
}

function Sidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const search = useRouterState({ select: (s) => s.location.search }) as { project?: number };
  const navigate = useNavigate();
  const { projects, username, email, avatarId, logout } = useWorkspace();
  const [projectOpen, setProjectOpen] = useState(false);
  const [deleteProjectOpen, setDeleteProjectOpen] = useState(false);
  const [projectToDelete, setProjectToDelete] = useState<{
    id: number;
    name: string;
  } | null>(null);
  const avatar = getAvatar(avatarId);
  
	const handleLogout = () => {
	  logout();

	  navigate({
		to: "/login",
	  });
	};

  return (
    <aside className="sticky top-0 flex h-screen w-[264px] shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      <div className="flex items-center gap-2 px-5 py-5">
        <div className="grid size-8 place-items-center rounded-xl bg-primary text-primary-foreground">
          <FolderKanban className="size-4" />
        </div>
        <span className="text-sm font-semibold tracking-tight">Tasky</span>
      </div>

      <div className="flex min-h-0 flex-1 flex-col px-3">
        <SectionLabel>Workspace</SectionLabel>
        <nav className="flex flex-col gap-1">
          {nav.map((item) => {
            const active = pathname === item.to;
            return (
              <Link
                key={item.to}
                to={item.to}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                  active && "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground",
                )}
              >
                <item.icon className="size-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <SectionLabel>Projects</SectionLabel>
        <div className="min-h-0 flex-1 overflow-y-auto pr-1">
          <ul className="flex flex-col gap-1 pb-2">
            {projects.map((p) => {
              const active = pathname === "/" && search?.project === p.id;
              return (
				<li key={p.id}>
				  <div
					className={cn(
					  "group flex items-center gap-1 rounded-lg transition-colors",
					  active && "bg-sidebar-accent",
					)}
				  >
					<button
					  onClick={() =>
						navigate({
						  to: "/",
						  search: { project: p.id },
						})
					  }
					  className={cn(
						"flex min-w-0 flex-1 items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-sidebar-foreground/75 transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
						active &&
						  "font-medium text-sidebar-accent-foreground",
					  )}
					>
					  <span className="size-1.5 shrink-0 rounded-full bg-primary/60" />

					  <span className="truncate">
						{p.name}
					  </span>
					</button>

					<button
					  type="button"
					  aria-label={`Delete ${p.name}`}
					  onClick={() => {
						setProjectToDelete({
						  id: p.id,
						  name: p.name,
						});
						setDeleteProjectOpen(true);
					  }}
					  className="mr-1 grid size-7 shrink-0 place-items-center rounded-lg text-muted-foreground opacity-0 transition-all hover:bg-destructive/10 hover:text-destructive group-hover:opacity-100"
					>
					  <Trash2 className="size-3.5" />
					</button>
				  </div>
				</li>
              );
            })}
          </ul>
        </div>

        <button
          onClick={() => setProjectOpen(true)}
          className="mt-2 mb-3 flex w-full items-center justify-center gap-2 rounded-lg border border-dashed border-primary/40 bg-primary/5 px-3 py-2 text-sm font-medium text-primary transition-colors hover:bg-primary/10"
        >
          <Plus className="size-4" />
          Create new project
        </button>
      </div>

      <div className="border-t border-sidebar-border p-3">
        <div className="flex items-center gap-3 px-2 py-2">
		<div
		  className={cn(
			"grid size-9 place-items-center overflow-hidden rounded-full",
			avatar.tint,
		  )}
		>
		  <img
			src={avatar.image}
			alt={avatar.label}
			className="size-7 object-contain"
		  />
		</div>
          <div className="min-w-0">
            <p className="truncate text-sm font-medium">{username}</p>
            <p className="truncate text-xs text-muted-foreground">{email}</p>
          </div>
        </div>
        <div className="mt-1 flex flex-col gap-1">
          <Link
            to="/profile"
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent",
              pathname === "/profile" && "bg-sidebar-accent text-sidebar-accent-foreground",
            )}
          >
            <User className="size-4" /> Profile
          </Link>
          <Link
            to="/settings"
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent",
              pathname === "/settings" && "bg-sidebar-accent text-sidebar-accent-foreground",
            )}
          >
            <Settings className="size-4" /> Settings
          </Link>
			<button
			  type="button"
			  onClick={handleLogout}
			  className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent"
			>
			  <LogOut className="size-4" />
			  Log out
			</button>
        </div>
      </div>

      <ProjectDialog open={projectOpen} onOpenChange={setProjectOpen} />
		<DeleteProjectDialog
		  open={deleteProjectOpen}
		  onOpenChange={(open) => {
			setDeleteProjectOpen(open);

			if (!open) {
			  setProjectToDelete(null);
			}
		  }}
		  project={projectToDelete}
		  onDeleted={(projectId) => {
			if (search?.project === projectId) {
			  navigate({
				to: "/",
				search: {
				  project: undefined,
				},
			  });
			}
		  }}
		/>
    </aside>
  );
}

export function AppShell({
  breadcrumb,
  title,
  subtitle,
  actions,
  children,
}: {
  breadcrumb: string[];
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-x-hidden">
        <div className="mx-auto w-full max-w-5xl px-8 py-10">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="text-xs text-muted-foreground">{breadcrumb.join(" / ")}</p>
              <h1 className="mt-2 text-3xl font-semibold tracking-tight">{title}</h1>
              {subtitle ? <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p> : null}
            </div>
            {actions}
          </div>
          <div className="mt-8">{children}</div>
        </div>
      </main>
    </div>
  );
}
