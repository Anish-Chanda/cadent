import { createRouter as createTanStackRouter } from '@tanstack/react-router'
import type { QueryClient } from '@tanstack/react-query'
import { routeTree } from './routeTree.gen'
import type { AuthState } from './contexts/auth-context'

export interface RouterContext {
  auth: AuthState
  queryClient: QueryClient
}

export const router = createTanStackRouter({
  routeTree,
  context: {
    auth: undefined!,
    queryClient: undefined!,
  } satisfies RouterContext,
  scrollRestoration: true,
  defaultPreload: 'intent',
  defaultPreloadStaleTime: 0,
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
