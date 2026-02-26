import React, { createContext, useContext } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { getCurrentUser, logout as apiLogout, type UserProfile } from '@/lib/api'

export interface AuthState {
  user: UserProfile | null
  isAuthenticated: boolean
  isLoading: boolean
  logout: () => Promise<void>
  invalidate: () => void
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const queryClient = useQueryClient()

  const { data: user, isLoading } = useQuery({
    queryKey: ['auth', 'currentUser'],
    queryFn: getCurrentUser,
    // Don't throw on 401 - treat it as "not authenticated"
    throwOnError: false,
    retry: false,
  })

  async function logout() {
    try {
      await apiLogout()
    } finally {
      // Always clear cached auth state so the router guard redirects to /login
      queryClient.removeQueries({ queryKey: ['auth'] })
    }
  }

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['auth', 'currentUser'] })
  }

  const value: AuthState = {
    user: user ?? null,
    isAuthenticated: !!user,
    isLoading,
    logout,
    invalidate,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error('useAuth must be used inside <AuthProvider>')
  }
  return ctx
}
