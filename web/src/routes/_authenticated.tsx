import { createFileRoute, Outlet, redirect, isRedirect } from '@tanstack/react-router'
import { getCurrentUser } from '@/lib/api'

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
  component: () => <Outlet />,
})
