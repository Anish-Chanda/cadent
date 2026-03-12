import { User } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { UserProfile } from '@/lib/api'

export function UserThumbnail({
  user,
  className,
}: {
  user: UserProfile | null
  className?: string
}) {
  const initials = user
    ? (user.name
        ? user.name
            .split(' ')
            .map((w) => w[0])
            .slice(0, 2)
            .join('')
            .toUpperCase()
        : user.email?.[0]?.toUpperCase() ?? 'U')
    : 'U'

  return (
    <>
      {initials.length > 0 && initials !== 'U' ? (
        <span className={cn('text-xs font-semibold', className)}>{initials}</span>
      ) : (
        <User className="size-4" />
      )}
    </>
  )
}

export default UserThumbnail
