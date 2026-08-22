import { Link } from "@tanstack/react-router";
import type { FormEvent, ReactNode, ChangeEvent } from "react";

export function AuthLayout({
  title,
  subtitle,
  children,
  footer,
  onSubmit,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
  footer: ReactNode;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex items-center justify-center gap-2">
          <span className="grid size-9 place-items-center rounded-xl bg-primary text-primary-foreground">
            T
          </span>

          <span className="text-lg font-semibold tracking-tight">
            Tasky
          </span>
        </div>

        <div className="surface p-7">
          <h1 className="text-xl font-semibold tracking-tight">
            {title}
          </h1>

          <p className="mt-1 text-sm text-muted-foreground">
            {subtitle}
          </p>

          <form
            className="mt-6 space-y-4"
            onSubmit={onSubmit}
          >
            {children}
          </form>
        </div>

        <p className="mt-5 text-center text-sm text-muted-foreground">
          {footer}
        </p>
      </div>
    </div>
  );
}

export function AuthField({
  label,
  id,
  type = "text",
  placeholder,
  value,
  onChange,
}: {
  label: string;
  id: string;
  type?: string;
  placeholder?: string;
  value?: string;
  onChange?: (event: ChangeEvent<HTMLInputElement>) => void;
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
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        className="mt-1.5 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-ring/40"
      />
    </div>
  );
}