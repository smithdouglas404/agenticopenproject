import { Home, FolderKanban, Calendar, BarChart3 } from 'lucide-react'
import { Link, useLocation } from 'react-router'
import { cn } from '@/lib/utils'

const navItems = [
  {
    label: 'Home',
    icon: Home,
    href: '/'
  },
  {
    label: 'Work Packages',
    icon: FolderKanban,
    href: '/work-packages'
  },
  {
    label: 'Calendar',
    icon: Calendar,
    href: '/calendar'
  },
  {
    label: 'Reports',
    icon: BarChart3,
    href: '/reports'
  }
]

export function BottomNav() {
  const location = useLocation()

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 pb-safe md:hidden">
      <div className="flex h-16 items-center justify-around">
        {navItems.map((item) => {
          const isActive = location.pathname === item.href
          const Icon = item.icon

          return (
            <Link
              key={item.href}
              to={item.href}
              className={cn(
                'flex min-w-0 flex-1 flex-col items-center justify-center gap-1 px-2 py-2 text-xs font-medium transition-colors touch-manipulation',
                isActive
                  ? 'text-primary'
                  : 'text-muted-foreground hover:text-foreground active:text-primary'
              )}
            >
              <Icon className={cn('h-5 w-5', isActive && 'fill-current')} />
              <span className="truncate">{item.label}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
