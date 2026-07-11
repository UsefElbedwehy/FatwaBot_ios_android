"use client";

import { useActionState } from "react";
import type { CollectionDef, FieldDef } from "@/lib/collections";
import type { FormState } from "@/lib/actions";
import type { LocaleInfo } from "@/lib/admin-api";

export function ContentForm({
  def,
  locales,
  action,
  initial,
  submitLabel,
}: {
  def: CollectionDef;
  locales: LocaleInfo[];
  action: (prevState: FormState, formData: FormData) => Promise<FormState>;
  initial?: Record<string, unknown>;
  submitLabel: string;
}) {
  const [state, formAction, pending] = useActionState<FormState, FormData>(action, {});

  return (
    <form action={formAction} className="mt-6 space-y-5">
      {def.fields.map((field) => (
        <FieldInput key={field.key} field={field} locales={locales} initial={initial?.[field.key]} />
      ))}
      {state.error && <p className="text-sm text-red-600">{state.error}</p>}
      {state.success && <p className="text-sm text-emerald-700">Saved.</p>}
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-[#7A2A2A] px-4 py-2 text-sm font-medium text-white hover:bg-[#5f2020] disabled:opacity-60"
      >
        {pending ? "Saving…" : submitLabel}
      </button>
    </form>
  );
}

function FieldInput({
  field,
  locales,
  initial,
}: {
  field: FieldDef;
  locales: LocaleInfo[];
  initial: unknown;
}) {
  const inputClass =
    "mt-1 w-full rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-none";

  if (field.kind === "translatable" || field.kind === "translatable-textarea") {
    const map = (initial as Record<string, string>) ?? {};
    return (
      <fieldset className="rounded-lg border border-stone-200 p-3">
        <legend className="px-1 text-sm font-medium text-stone-700">{field.label}</legend>
        <div className="space-y-2">
          {locales.map((loc) => (
            <div key={loc.locale}>
              <label className="text-xs text-stone-500">{loc.display_name}</label>
              {field.kind === "translatable-textarea" ? (
                <textarea
                  name={`${field.key}.${loc.locale}`}
                  defaultValue={map[loc.locale] ?? ""}
                  dir={loc.direction}
                  rows={2}
                  className={inputClass}
                />
              ) : (
                <input
                  name={`${field.key}.${loc.locale}`}
                  defaultValue={map[loc.locale] ?? ""}
                  dir={loc.direction}
                  className={inputClass}
                />
              )}
            </div>
          ))}
        </div>
      </fieldset>
    );
  }

  if (field.kind === "boolean") {
    return (
      <div className="flex items-center gap-2">
        <input
          id={field.key}
          name={field.key}
          type="checkbox"
          defaultChecked={initial === true}
          className="h-4 w-4 rounded border-stone-300"
        />
        <label className="text-sm font-medium text-stone-700" htmlFor={field.key}>
          {field.label}
        </label>
      </div>
    );
  }

  if (field.kind === "json" || field.kind === "array") {
    const defaultValue =
      field.kind === "array"
        ? ((initial as string[]) ?? []).join("\n")
        : JSON.stringify(initial ?? (field.kind === "json" ? {} : []), null, 2);
    return (
      <div>
        <label className="block text-sm font-medium text-stone-700" htmlFor={field.key}>
          {field.label}
        </label>
        <p className="mt-0.5 text-xs text-stone-400">
          {field.kind === "array" ? "One value per line." : "Raw JSON — edited as data, not code."}
        </p>
        <textarea
          id={field.key}
          name={field.key}
          defaultValue={defaultValue}
          rows={field.kind === "json" ? 6 : 3}
          className={`${inputClass} font-mono text-xs`}
        />
      </div>
    );
  }

  return (
    <div>
      <label className="block text-sm font-medium text-stone-700" htmlFor={field.key}>
        {field.label}
      </label>
      {field.kind === "textarea" ? (
        <textarea
          id={field.key}
          name={field.key}
          defaultValue={(initial as string) ?? ""}
          dir="rtl"
          rows={3}
          className={inputClass}
        />
      ) : (
        <input
          id={field.key}
          name={field.key}
          type={field.kind === "number" ? "number" : "text"}
          defaultValue={(initial as string | number | undefined) ?? ""}
          className={inputClass}
        />
      )}
    </div>
  );
}
