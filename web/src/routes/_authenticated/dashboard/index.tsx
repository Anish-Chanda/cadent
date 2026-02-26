import { createFileRoute, useRouter } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/contexts/auth-context'

export const Route = createFileRoute('/_authenticated/dashboard/')({
  component: DashboardPage,
})

function DashboardPage() {
  const auth = useAuth()
  const router = useRouter()

  async function handleLogout() {
    await auth.logout()
    router.navigate({ to: '/login', search: { redirect: undefined } })
  }

  return (
    <div className="p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <Button variant="outline" onClick={handleLogout}>
          Log out
        </Button>
      </div>
    </div>
  )
}
