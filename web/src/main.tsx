import ReactDOM from 'react-dom/client'
import { RouterProvider } from '@tanstack/react-router'
import { QueryClientProvider } from '@tanstack/react-query'

import { router } from './router'
import { queryClient } from './lib/query-client'
import { AuthProvider, useAuth } from './contexts/auth-context'

function InnerApp() {
  const auth = useAuth()
  return <RouterProvider router={router} context={{ auth, queryClient }} />
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <InnerApp />
      </AuthProvider>
    </QueryClientProvider>
  )
}

const rootElement = document.getElementById('app')!

if (!rootElement.innerHTML) {
  const root = ReactDOM.createRoot(rootElement)
  root.render(<App />)
}
