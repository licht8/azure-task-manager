import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import {
  getTasks,
  createTaskRequest,
  updateTaskRequest,
  deleteTaskRequest,
} from "@/api/tasks";

import {
  getProjects,
  createProjectRequest,
  type ApiProject,
} from "@/api/projects";

import { apiTaskToTask } from "@/api/adapters";

import {
  getCurrentUser,
  updateProfileRequest,
} from "@/api/auth";

import type {
  Task,
  TaskPriority,
  TaskStatus,
} from "@/types/task"

export type Project = {
  id: number;
  name: string;
};

export type TaskInput = {
  title: string;
  description: string;
  projectId: number | null;
  status: TaskStatus;
  priority: TaskPriority;
  due: string;
};

type Store = {
  tasks: Task[];
  projects: Project[];
  loading: boolean;

  username: string;
  email: string;
  role: string;

  avatarId: number;
  setAvatarId: (id: number) => void;
  setUsername: (name: string) => void;
  updateProfile: (username: string, avatarId: number) => Promise<void>;
  
  logout: () => void;

  createTask: (input: TaskInput) => Promise<void>;
  updateTask: (id: number, input: TaskInput) => Promise<void>;
  deleteTask: (id: number) => Promise<void>;

  createProject: (
  name: string,
  taskIds: number[],
) => Promise<void>;

  projectName: (id: number | null | undefined) => string;

  reloadTasks: () => Promise<void>;
  reloadProjects: () => Promise<void>;
};

const StoreContext = createContext<Store | null>(null);

function apiProjectToProject(project: ApiProject): Project {
  return {
    id: project.id,
    name: project.name,
  };
}

function toApiTask(input: TaskInput) {
  return {
    title: input.title,
    description: input.description,
    project_id: input.projectId,
    status:
      input.status === "in-progress"
        ? "in_progress"
        : input.status,
    priority: input.priority,
    due_date: input.due || null,
  };
}

export function WorkspaceProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);

  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState("User");
  const [avatarId, setAvatarId] = useState(1);

  async function reloadTasks() {
    const data = await getTasks();
    setTasks(data.map(apiTaskToTask));
  }

  async function reloadProjects() {
    const data = await getProjects();
    setProjects(data.map(apiProjectToProject));
  }

	  useEffect(() => {
	  const token = localStorage.getItem("access_token");

	  if (!token) {
		setLoading(false);
		return;
	  }

	  async function loadWorkspace() {
		try {
		  setLoading(true);

		  const [user] = await Promise.all([
			getCurrentUser(),
			reloadTasks(),
			reloadProjects(),
		  ]);

		  setUsername(user.username);
		  setEmail(user.email);
		  setAvatarId(
			Number(user.avatar.replace("avatar-", ""))
		  );
		} catch (error) {
		  console.error("Failed to load workspace:", error);
		} finally {
		  setLoading(false);
		}
	  }

	  loadWorkspace();
	}, []);

  const value = useMemo<Store>(
    () => ({
      tasks,
      projects,
      loading,

      username,
      email,
      role,

      avatarId,
      setAvatarId,
      setUsername,
	  
		logout: () => {
		  localStorage.removeItem("access_token");

		  setTasks([]);
		  setProjects([]);
		  setUsername("");
		  setEmail("");
		  setAvatarId(1);
		},
	  
		updateProfile: async (username, avatarId) => {
		  const user = await updateProfileRequest(
			username,
			`avatar-${String(avatarId).padStart(2, "0")}`,
		  );

		  setUsername(user.username);
		  setAvatarId(
			Number(user.avatar.replace("avatar-", "")),
		  );
		},

      createTask: async (input) => {
        const created = await createTaskRequest(
          toApiTask(input)
        );

        setTasks((prev) => [
          apiTaskToTask(created),
          ...prev,
        ]);
      },

      updateTask: async (id, input) => {
        const updated = await updateTaskRequest(
          id,
          toApiTask(input)
        );

        setTasks((prev) =>
          prev.map((task) =>
            task.id === id
              ? apiTaskToTask(updated)
              : task
          )
        );
      },

      deleteTask: async (id) => {
        await deleteTaskRequest(id);

        setTasks((prev) =>
          prev.filter((task) => task.id !== id)
        );
      },

	createProject: async (name, taskIds) => {
	  const created = await createProjectRequest(name);

	  setProjects((prev) => [
		...prev,
		apiProjectToProject(created),
	  ]);

	  for (const taskId of taskIds) {
		const task = tasks.find((t) => t.id === taskId);

		if (!task) continue;

		await updateTaskRequest(taskId, {
		  title: task.title,
		  description: task.description,
		  project_id: created.id,
		  status:
			task.status === "in-progress"
			  ? "in_progress"
			  : task.status,
		  priority: task.priority,
		  due_date: task.due || null,
		});
	  }

	  await reloadTasks();
	},

      projectName: (id) => {
        if (id == null) {
          return "No project";
        }

        return (
          projects.find((project) => project.id === id)?.name ??
          "No project"
        );
      },

      reloadTasks,
      reloadProjects,
    }),
    [
      tasks,
      projects,
      loading,
      username,
      avatarId,
    ]
  );

  return (
    <StoreContext.Provider value={value}>
      {children}
    </StoreContext.Provider>
  );
}

export function useWorkspace() {
  const context = useContext(StoreContext);

  if (!context) {
    throw new Error(
      "useWorkspace must be used inside WorkspaceProvider"
    );
  }

  return context;
}