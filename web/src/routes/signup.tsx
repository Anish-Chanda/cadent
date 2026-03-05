import { useState } from 'react'
import {
  createFileRoute,
  redirect,
  useRouter,
  isRedirect,
} from '@tanstack/react-router'
import { LoginForm, type LoginFormFields } from '@/components/login-form'
import { useAuth } from '@/contexts/auth-context'
import { signup, login, getCurrentUser, ApiError } from '@/lib/api'

export const Route = createFileRoute('/signup')({
  beforeLoad: async ({ context }) => {
    try {
      await context.queryClient.ensureQueryData({
        queryKey: ['auth', 'currentUser'],
        queryFn: getCurrentUser,
      })
      throw redirect({ to: '/dashboard' })
    } catch (error) {
      if (isRedirect(error)) throw error
      // Not authenticated — allow signup page to render
    }
  },
  component: SignupPage,
})

function SignupPage() {
  const auth = useAuth()
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(fields: LoginFormFields) {
    if (!fields.name) {
      setError('Name is required.')
      return
    }

    setError(null)
    setIsLoading(true)

    try {
      await signup({ user: fields.email, passwd: fields.password, name: fields.name })
      // Log the user in immediately after signup
      await login({ user: fields.email, passwd: fields.password })
      auth.invalidate()
      router.navigate({ to: '/dashboard' })
    } catch (err) {
      if (err instanceof ApiError) {
        if (err.status === 409) {
          setError('An account with this email already exists.')
        } else {
          setError('Failed to create account. Please try again.')
        }
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
          mode="signup"
          onSubmit={handleSubmit}
          isLoading={isLoading}
          error={error}
        />
      </div>
    </div>
  )
}
