import { QueryClient } from '@tanstack/react-query'

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: (failureCount, error) => {
        // Don't retry on 401 Unauthorized
        if (error instanceof Error && 'status' in error && (error as { status: number }).status === 401) {
          return false
        }
        return failureCount < 2
      },
    },
  },
})
