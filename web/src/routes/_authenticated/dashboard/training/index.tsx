import { createFileRoute, redirect } from "@tanstack/react-router"

export const Route = createFileRoute("/_authenticated/dashboard/training/")({
  beforeLoad: () => {
    throw redirect({ to: "/dashboard/training/calendar" })
  },
})
