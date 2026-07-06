import { LoginForm } from "./LoginForm";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const { next } = await searchParams;

  return (
    <div className="flex min-h-screen items-center justify-center bg-stone-100">
      <div className="w-full max-w-sm rounded-xl border border-stone-200 bg-white p-6 shadow-sm">
        <p className="text-lg font-semibold text-[#7A2A2A]">Fatwa Bot</p>
        <h1 className="mt-1 text-sm text-stone-500">Sign in to the control center</h1>
        <LoginForm next={next} />
      </div>
    </div>
  );
}
