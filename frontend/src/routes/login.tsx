import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { apiFetch } from "@/api/client";
import { AuthField, AuthLayout } from "@/components/auth-card";

export const Route = createFileRoute("/login")({
  head: () => ({
    meta: [
      { title: "Log in — Tasky Workspace" },
      {
        name: "description",
        content: "Sign in to your Tasky workspace to manage tasks and projects.",
      },
      {
        property: "og:title",
        content: "Log in — Tasky Workspace",
      },
      {
        property: "og:description",
        content: "Sign in to your Tasky workspace to manage tasks and projects.",
      },
    ],
  }),
  component: LoginPage,
});

function LoginPage() {
  const navigate = useNavigate();

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleLogin(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    setError("");
    setLoading(true);

    try {
      const body = new URLSearchParams();

      body.append("username", username);
      body.append("password", password);

      const response = await apiFetch("/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body,
      });

		if (!response.ok) {
		  let message = "Invalid username or password.";

		  try {
			const data = await response.json();

			if (typeof data.detail === "string") {
			  message = data.detail;
			}
		  } catch {
			// Response does not contain JSON.
		  }

		  if (response.status === 401) {
			message = "Invalid username or password.";
		  } else if (response.status >= 500) {
			message = "Server error. Please try again later.";
		  }

		  throw new Error(message);
		}

      const data = await response.json();

		localStorage.setItem(
		  "access_token",
		  data.access_token
		);

		window.location.href = "/";

	} catch (error) {
	  console.error("Login failed:", error);

	  setError(
		error instanceof Error
		  ? error.message
		  : "Unable to log in. Please try again.",
	  );
	} finally {
      setLoading(false);
    }
  }

  return (
    <AuthLayout
      title="Welcome back"
      subtitle="Log in to continue to your workspace"
      footer={
        <>
          No account yet?{" "}
          <Link
            to="/register"
            className="font-medium text-primary hover:underline"
          >
            Create one
          </Link>
        </>
      }
      onSubmit={handleLogin}
    >
      <AuthField
        label="Username"
        id="username"
        placeholder="your_username"
        value={username}
        onChange={(event) =>
          setUsername(event.target.value)
        }
      />

      <AuthField
        label="Password"
        id="password"
        type="password"
        placeholder="••••••••"
        value={password}
        onChange={(event) =>
          setPassword(event.target.value)
        }
      />

      {error ? (
        <div className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {loading ? "Logging in..." : "Log in"}
      </button>
    </AuthLayout>
  );
}