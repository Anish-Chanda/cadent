import { useState } from 'react'
import {
  createFileRoute,
  redirect,
  useRouter,
  isRedirect,
} from '@tanstack/react-router'
import { LoginForm, type LoginFormFields } from '@/components/login-form'
import { useAuth } from '@/contexts/auth-context'
import { login, getCurrentUser, ApiError } from '@/lib/api'
export const Route = createFileRoute('/login')({
  validateSearch: (search: Record<string, unknown>) => ({
    redirect: typeof search.redirect === 'string' ? search.redirect : undefined,
  }),
  beforeLoad: async ({ context, location: _location }) => {
    try {
      await context.queryClient.ensureQueryData({
        queryKey: ['auth', 'currentUser'],
        queryFn: getCurrentUser,
      })
      // User is authenticated — redirect away from login
      throw redirect({ to: '/dashboard' })
    } catch (error) {
      if (isRedirect(error)) throw error
      // Not authenticated — let the login page render
    }
  },
  component: LoginPage,
})

function LoginPage() {
  const auth = useAuth()
  const router = useRouter()
  const { redirect: redirectTo } = Route.useSearch()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(fields: LoginFormFields) {
    setError(null)
    setIsLoading(true)

    try {
      await login({ user: fields.email, passwd: fields.password })
      auth.invalidate()

      if (redirectTo) {
        router.history.push(redirectTo)
      } else {
        router.navigate({ to: '/dashboard' })
      }
    } catch (err) {
      if (err instanceof ApiError && err.status === 403) {
        setError('Invalid email or password.')
      } else {
        setError('Something went wrong. Please try again.')
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="flex min-h-svh items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <LoginForm
          mode="login"
          onSubmit={handleSubmit}
          isLoading={isLoading}
          error={error}
        />
      </div>
    </div>
  )
}
