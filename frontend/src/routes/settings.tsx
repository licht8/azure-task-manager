import { requireAuth } from "@/lib/require-auth";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell } from "@/components/app-shell";
import { changePassword } from "@/api/auth";
import { useWorkspace } from "@/data/store";

export const Route = createFileRoute("/settings")({
  beforeLoad: () => {
    requireAuth();
  },
  head: () => ({
    meta: [
      { title: "Settings — Tasky Workspace" },
      {
        name: "description",
        content:
          "Manage your account details and update your password securely.",
      },
      {
        property: "og:title",
        content: "Settings — Tasky Workspace",
      },
      {
        property: "og:description",
        content:
          "Manage your account details and update your password securely.",
      },
    ],
  }),
  component: SettingsPage,
});

function Row({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center justify-between border-b border-border py-3 last:border-b-0">
      <span className="text-sm text-muted-foreground">
        {label}
      </span>

      <span className="text-sm font-medium">
        {value}
      </span>
    </div>
  );
}

function Field({
  label,
  id,
  value,
  onChange,
}: {
  label: string;
  id: string;
  value: string;
  onChange: (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => void;
}) {
  return (
    <div>
      <label
        className="text-sm font-medium"
        htmlFor={id}
      >
        {label}
      </label>

      <input
        id={id}
        type="password"
        value={value}
        onChange={onChange}
        placeholder="••••••••"
        className="mt-1.5 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring/40"
      />
    </div>
  );
}

function SettingsPage() {
  const {
    username,
    email,
    role,
  } = useWorkspace();

  const [currentPassword, setCurrentPassword] =
    useState("");

  const [newPassword, setNewPassword] =
    useState("");

  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [changing, setChanging] =
    useState(false);

  const [message, setMessage] =
    useState("");

  async function handleChangePassword(
    e: React.FormEvent<HTMLFormElement>,
  ) {
    e.preventDefault();

    setMessage("");

    if (
      !currentPassword ||
      !newPassword ||
      !confirmPassword
    ) {
      setMessage(
        "Please fill in all password fields.",
      );
      return;
    }

    if (newPassword !== confirmPassword) {
      setMessage(
        "New passwords do not match.",
      );
      return;
    }

    setChanging(true);

    try {
      await changePassword(
        currentPassword,
        newPassword,
      );

      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");

      setMessage(
        "Password changed successfully.",
      );
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Failed to change password.",
      );
    } finally {
      setChanging(false);
    }
  }

  return (
    <AppShell
      breadcrumb={["Settings"]}
      title="Settings"
      subtitle="Manage your account and security"
    >
      <div className="grid gap-4 lg:grid-cols-2">
        <section className="surface p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Account
          </p>

          <h2 className="mt-1 text-base font-semibold">
            Account information
          </h2>

          <p className="text-sm text-muted-foreground">
            Your current account details
          </p>

          <div className="mt-5">
            <Row
              label="Username"
              value={username}
            />

            <Row
              label="Email"
              value={email}
            />

            <Row
              label="Role"
              value={role}
            />
          </div>
        </section>

        <section className="surface p-6">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Security
          </p>

          <h2 className="mt-1 text-base font-semibold">
            Change password
          </h2>

          <p className="text-sm text-muted-foreground">
            Update your account password
          </p>

          <form
            className="mt-5 space-y-4"
            onSubmit={handleChangePassword}
          >
            <Field
              label="Current password"
              id="current"
              value={currentPassword}
              onChange={(e) =>
                setCurrentPassword(
                  e.target.value,
                )
              }
            />

            <Field
              label="New password"
              id="new"
              value={newPassword}
              onChange={(e) =>
                setNewPassword(
                  e.target.value,
                )
              }
            />

            <Field
              label="Confirm new password"
              id="confirm"
              value={confirmPassword}
              onChange={(e) =>
                setConfirmPassword(
                  e.target.value,
                )
              }
            />

            {message && (
              <div className="rounded-lg bg-primary/10 px-3 py-2 text-sm">
                {message}
              </div>
            )}

            <button
              type="submit"
              disabled={changing}
              className="w-full rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {changing
                ? "Updating..."
                : "Update password"}
            </button>
          </form>
        </section>
      </div>
    </AppShell>
  );
}