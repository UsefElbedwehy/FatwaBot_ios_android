"use client";

import { useActionState } from "react";
import { loginAction, type FormState } from "@/lib/actions";

export function LoginForm({ next }: { next?: string }) {
  const [state, formAction, pending] = useActionState<FormState, FormData>(loginAction, {});

  return (
    <form action={formAction} className="mt-6 space-y-4">
      <input type="hidden" name="next" value={next ?? "/content"} />
      <div>
        <label className="block text-sm font-medium text-stone-700" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="username"
          className="mt-1 w-full rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-none"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-stone-700" htmlFor="password">
          Password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          required
          autoComplete="current-password"
          className="mt-1 w-full rounded-lg border border-stone-300 px-3 py-2 text-sm focus:border-[#7A2A2A] focus:outline-none"
        />
      </div>
      {state.error && <p className="text-sm text-red-600">{state.error}</p>}
      <button
        type="submit"
        disabled={pending}
        className="w-full rounded-lg bg-[#7A2A2A] px-3 py-2 text-sm font-medium text-white hover:bg-[#5f2020] disabled:opacity-60"
      >
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
