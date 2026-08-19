"use client";

import { useActionState, useMemo, useState } from "react";
import type { FormState } from "@/lib/actions";

function omit(map: Record<string, string>, key: string): Record<string, string> {
  const next = { ...map };
  delete next[key];
  return next;
}

/** Key/value editor for one locale's string pack.
 *
 * Keys are not editable in place — a rename is a remove plus an add, which keeps
 * the state a plain map and makes duplicate keys impossible. Removals are held
 * as "pending" until save so a mis-click is recoverable without reloading.
 *
 * The whole map is submitted as one hidden JSON field (see saveStringPackAction):
 * rows are added and removed client-side, so per-key form fields would have to be
 * reconciled on both ends for no gain. */
export function StringPackEditor({
  locale,
  direction,
  initialStrings,
  action,
  isNewPack,
}: {
  locale: string;
  direction: "ltr" | "rtl";
  initialStrings: Record<string, string>;
  action: (prevState: FormState, formData: FormData) => Promise<FormState>;
  isNewPack: boolean;
}) {
  const [state, formAction, pending] = useActionState<FormState, FormData>(action, {});
  const [strings, setStrings] = useState<Record<string, string>>(initialStrings);
  const [removed, setRemoved] = useState<Record<string, string>>({});
  const [filter, setFilter] = useState("");
  const [newKey, setNewKey] = useState("");
  const [newValue, setNewValue] = useState("");
  const [addError, setAddError] = useState<string | null>(null);

  const sorted = useMemo(
    () => Object.keys(strings).sort((a, b) => a.localeCompare(b)),
    [strings],
  );
  const needle = filter.trim().toLowerCase();
  const visible = needle.length === 0
    ? sorted
    : sorted.filter((k) => k.toLowerCase().includes(needle) || strings[k].toLowerCase().includes(needle));

  const removedKeys = Object.keys(removed);
  const dirty = removedKeys.length > 0 ||
    Object.keys(initialStrings).length !== sorted.length ||
    sorted.some((k) => initialStrings[k] !== strings[k]);

  function addKey() {
    const key = newKey.trim();
    if (key.length === 0) return setAddError("Key is required.");
    if (Object.hasOwn(strings, key)) return setAddError(`"${key}" already exists in this pack.`);
    setStrings({ ...strings, [key]: newValue });
    // Re-adding a key that was just removed cancels the pending removal,
    // otherwise it would sit in both maps and read as "will be dropped".
    setRemoved(omit(removed, key));
    setNewKey("");
    setNewValue("");
    setAddError(null);
  }

  function removeKey(key: string) {
    setRemoved({ ...removed, [key]: strings[key] });
    setStrings(omit(strings, key));
  }

  function restoreRemoved() {
    setStrings({ ...removed, ...strings });
    setRemoved({});
  }

  const inputClass =
    "w-full rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-2 focus:outline-offset-1 focus:outline-[#7A2A2A]";
  const buttonFocus = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#7A2A2A]";

  return (
    <form action={formAction} className="mt-6">
      <input type="hidden" name="strings" value={JSON.stringify(strings)} />

      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-64 flex-1">
          <label htmlFor="string-filter" className="block text-sm font-medium text-stone-700">
            Filter keys and values
          </label>
          <input
            id="string-filter"
            type="search"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder="e.g. tasbeeh"
            className={`mt-1 ${inputClass}`}
          />
        </div>
        <p className="text-sm text-stone-500">
          {visible.length} of {sorted.length} keys
          {dirty && <span className="ms-2 font-medium text-amber-700">unsaved changes</span>}
        </p>
      </div>

      {removedKeys.length > 0 && (
        <div className="mt-3 flex flex-wrap items-center gap-3 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          <span>
            {removedKeys.length} key{removedKeys.length === 1 ? "" : "s"} will be dropped from the next version:{" "}
            <span className="font-mono text-xs">{removedKeys.sort().join(", ")}</span>
          </span>
          <button
            type="button"
            onClick={restoreRemoved}
            className={`rounded-lg border border-amber-400 px-2 py-1 text-xs font-medium hover:bg-amber-100 ${buttonFocus}`}
          >
            Restore all
          </button>
        </div>
      )}

      <ul className="mt-4 divide-y divide-stone-100 overflow-hidden rounded-xl border border-stone-200 bg-white">
        {visible.map((key) => (
          <li key={key} className="flex flex-col gap-2 p-3 sm:flex-row sm:items-start">
            <label htmlFor={`value-${key}`} className="w-full break-all pt-2 font-mono text-xs text-stone-600 sm:w-64">
              {key}
            </label>
            <textarea
              id={`value-${key}`}
              value={strings[key]}
              dir={direction}
              rows={2}
              onChange={(e) => setStrings({ ...strings, [key]: e.target.value })}
              className={`${inputClass} flex-1`}
            />
            <button
              type="button"
              onClick={() => removeKey(key)}
              aria-label={`Remove ${key}`}
              className={`rounded-lg border border-stone-300 px-3 py-2 text-sm font-medium text-stone-600 hover:bg-stone-50 ${buttonFocus}`}
            >
              Remove
            </button>
          </li>
        ))}
        {visible.length === 0 && (
          <li className="p-6 text-center text-sm text-stone-400">
            {sorted.length === 0 ? "This pack has no keys yet — add the first one below." : "No keys match the filter."}
          </li>
        )}
      </ul>

      <fieldset className="mt-4 rounded-xl border border-stone-200 bg-white p-3">
        <legend className="px-1 text-sm font-medium text-stone-700">Add a key</legend>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start">
          <div className="w-full sm:w-64">
            <label htmlFor="new-key" className="sr-only">
              New key
            </label>
            <input
              id="new-key"
              value={newKey}
              onChange={(e) => setNewKey(e.target.value)}
              placeholder="tasbeeh.notice"
              className={`${inputClass} font-mono text-xs`}
            />
          </div>
          <div className="flex-1">
            <label htmlFor="new-value" className="sr-only">
              New value
            </label>
            <textarea
              id="new-value"
              value={newValue}
              dir={direction}
              rows={2}
              onChange={(e) => setNewValue(e.target.value)}
              placeholder="Copy shown in the app"
              className={inputClass}
            />
          </div>
          <button
            type="button"
            onClick={addKey}
            className={`rounded-lg border border-stone-300 px-3 py-2 text-sm font-medium hover:bg-stone-50 ${buttonFocus}`}
          >
            Add
          </button>
        </div>
        {addError && (
          <p role="alert" className="mt-2 text-sm text-red-600">
            {addError}
          </p>
        )}
      </fieldset>

      <div className="mt-5 rounded-xl border border-stone-200 bg-white p-4">
        <p className="text-sm text-stone-600">
          Both buttons create a <span className="font-medium">new version</span> of the {locale} pack — nothing is
          edited in place. <span className="font-medium">Publish</span> makes that version the one the apps download on
          their next sync; a draft stays invisible to them until you publish it.
        </p>
        <div className="mt-3 flex flex-wrap gap-3">
          <button
            type="submit"
            name="intent"
            value="draft"
            disabled={pending}
            className={`rounded-lg border border-stone-300 px-4 py-2 text-sm font-medium hover:bg-stone-50 disabled:opacity-60 ${buttonFocus}`}
          >
            {pending ? "Saving…" : "Save as draft"}
          </button>
          <button
            type="submit"
            name="intent"
            value="publish"
            disabled={pending}
            className={`rounded-lg bg-emerald-700 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-800 disabled:opacity-60 ${buttonFocus}`}
          >
            {pending ? "Publishing…" : isNewPack ? "Create & publish" : "Publish new version"}
          </button>
        </div>
        {state.error && (
          <p role="alert" className="mt-3 text-sm text-red-600">
            {state.error}
          </p>
        )}
        {state.success && (
          <p role="status" className="mt-3 text-sm text-emerald-700">
            {state.message ?? "Saved."}
          </p>
        )}
      </div>
    </form>
  );
}
