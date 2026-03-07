import { createFileRoute, Outlet, redirect, isRedirect } from '@tanstack/react-router'
import { getCurrentUser } from '@/lib/api'
import { TopBar } from '@/components/top-bar'

export const Route = createFileRoute('/_authenticated')({
  beforeLoad: async ({ context, location }) => {
    try {
      await context.queryClient.ensureQueryData({
        queryKey: ['auth', 'currentUser'],
        queryFn: getCurrentUser,
      })
    } catch (error) {
      if (isRedirect(error)) throw error

      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }
  },
  component: AuthenticatedLayout,
})

function AuthenticatedLayout() {
  return (
    <div className="min-h-screen flex flex-col">
      <TopBar />
      <main className="flex-1">
        <div className="mx-auto w-full max-w-screen-2xl">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
