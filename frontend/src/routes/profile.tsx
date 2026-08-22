import { requireAuth } from "@/lib/require-auth";
import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { AppShell } from "@/components/app-shell";
import { avatars, getAvatar } from "@/data/avatars";
import { useWorkspace } from "@/data/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/profile")({
  beforeLoad: () => {
    requireAuth();
  },
  head: () => ({
    meta: [
      { title: "Profile — Tasky Workspace" },
      {
        name: "description",
        content: "Manage your username and choose a profile avatar.",
      },
      {
        property: "og:title",
        content: "Profile — Tasky Workspace",
      },
      {
        property: "og:description",
        content: "Manage your username and choose a profile avatar.",
      },
    ],
  }),
  component: ProfilePage,
});

function ProfilePage() {
  const {
    username,
    email,
    avatarId,
    updateProfile,
  } = useWorkspace();

  const [draftName, setDraftName] =
    useState(username);

  const [draftAvatar, setDraftAvatar] =
    useState(avatarId);

  const [saving, setSaving] =
    useState(false);

  const [message, setMessage] =
    useState("");

  useEffect(() => {
    setDraftName(username);
    setDraftAvatar(avatarId);
  }, [username, avatarId]);

  async function save(
    e: React.FormEvent<HTMLFormElement>,
  ) {
    e.preventDefault();

    const name = draftName.trim();

    if (!name) {
      setMessage("Username cannot be empty.");
      return;
    }

    setSaving(true);
    setMessage("");

    try {
      await updateProfile(
        name,
        draftAvatar,
      );

      setMessage(
        "Profile updated successfully.",
      );
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Failed to update profile.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell
      breadcrumb={["Profile"]}
      title="Profile"
      subtitle="Manage your account information"
    >
      <section className="surface p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Account
        </p>

        <h2 className="mt-1 text-base font-semibold">
          Your profile
        </h2>

        <p className="text-sm text-muted-foreground">
          Update your username and profile avatar
        </p>

        <form
          className="mt-6"
          onSubmit={save}
        >
          <div>
            <p className="text-sm font-medium">
              Profile avatar
            </p>

            <p className="text-xs text-muted-foreground">
              Choose one of the available avatars
            </p>

            <div className="mt-3 flex flex-wrap gap-3">
              {avatars.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  title={a.label}
                  onClick={() =>
                    setDraftAvatar(a.id)
                  }
                  className={cn(
                    "grid size-12 place-items-center rounded-full border border-border text-xl transition-all hover:scale-105",
                    a.tint,
                    draftAvatar === a.id &&
                      "border-primary ring-2 ring-primary/40",
                  )}
                >
                  {a.emoji}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div>
              <label
                className="text-sm font-medium"
                htmlFor="username"
              >
                Username
              </label>

              <input
                id="username"
                value={draftName}
                onChange={(e) =>
                  setDraftName(
                    e.target.value,
                  )
                }
                className="mt-1.5 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring/40"
              />
            </div>

            <div>
              <label
                className="text-sm font-medium"
                htmlFor="email"
              >
                Email
              </label>

              <input
                id="email"
                value={email}
                disabled
                className="mt-1.5 w-full rounded-lg border border-input bg-muted px-3 py-2 text-sm text-muted-foreground"
              />

              <p className="mt-1 text-xs text-muted-foreground">
                Email address cannot be changed here.
              </p>
            </div>
          </div>

          <div className="mt-6 flex items-center gap-3 rounded-xl bg-secondary px-4 py-3">
            <span
              className={cn(
                "grid size-10 place-items-center rounded-full text-xl",
                getAvatar(draftAvatar).tint,
              )}
            >
              {getAvatar(draftAvatar).emoji}
            </span>

            <div>
              <p className="text-xs text-muted-foreground">
                Selected avatar
              </p>

              <p className="text-sm font-medium">
                {draftName}
              </p>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="ml-auto rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {saving
                ? "Saving..."
                : "Save changes"}
            </button>
          </div>

          {message && (
            <div className="mt-3 rounded-lg bg-primary/10 px-3 py-2 text-sm">
              {message}
            </div>
          )}
        </form>
      </section>
    </AppShell>
  );
}