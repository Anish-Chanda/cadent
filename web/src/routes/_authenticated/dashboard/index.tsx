import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated/dashboard/')({
  component: DashboardPage,
})

function DashboardPage() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-semibold">Activity Feed</h1>
    </div>
  )
}
