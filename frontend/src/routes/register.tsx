import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { apiFetch } from "@/api/client";
import { AuthField, AuthLayout } from "@/components/auth-card";

export const Route = createFileRoute("/register")({
  head: () => ({
    meta: [
      { title: "Sign up — Tasky Workspace" },
      {
        name: "description",
        content: "Create a Tasky account and organise your tasks and projects.",
      },
      {
        property: "og:title",
        content: "Sign up — Tasky Workspace",
      },
      {
        property: "og:description",
        content: "Create a Tasky account and organise your tasks and projects.",
      },
    ],
  }),
  component: RegisterPage,
});

function RegisterPage() {
  const navigate = useNavigate();

  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleRegister(
    event: React.FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    setError("");

    if (password !== confirm) {
      setError("Passwords do not match");
      return;
    }

    setLoading(true);

    try {
      const response = await apiFetch("/auth/register", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          username,
          email,
          password,
        }),
      });

      if (!response.ok) {
        let message = "Registration failed";

        try {
          const data = await response.json();

          if (data.detail) {
            message = data.detail;
          }
        } catch {
          // Ignore JSON parsing errors
        }

        throw new Error(message);
      }

      navigate({ to: "/login" });
    } catch (error) {
      console.error("Registration failed:", error);

      setError(
        error instanceof Error
          ? error.message
          : "Registration failed",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthLayout
      title="Create your account"
      subtitle="Start organising your work in minutes"
      footer={
        <>
          Already have an account?{" "}
          <Link
            to="/login"
            className="font-medium text-primary hover:underline"
          >
            Log in
          </Link>
        </>
      }
      onSubmit={handleRegister}
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
        label="Email"
        id="email"
        type="email"
        placeholder="you@example.com"
        value={email}
        onChange={(event) =>
          setEmail(event.target.value)
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

      <AuthField
        label="Confirm password"
        id="confirm"
        type="password"
        placeholder="••••••••"
        value={confirm}
        onChange={(event) =>
          setConfirm(event.target.value)
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
        {loading ? "Creating account..." : "Create account"}
      </button>
    </AuthLayout>
  );
}