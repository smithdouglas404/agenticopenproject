import { Home, FolderKanban, Calendar, BarChart3, Settings, X } from 'lucide-react'
import { Link, useLocation } from 'react-router'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'

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
  },
  {
    label: 'Settings',
    icon: Settings,
    href: '/settings'
  }
]

interface SidebarProps {
  open: boolean
  onClose: () => void
}

export function Sidebar({ open, onClose }: SidebarProps) {
  const location = useLocation()

  return (
    <>
      {/* Mobile overlay */}
      {open && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={onClose}
          aria-hidden="true"
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          'fixed left-0 top-0 z-50 h-full w-64 border-r bg-background transition-transform duration-300 md:static md:translate-x-0',
          open ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <div className="flex h-full flex-col">
          {/* Header */}
          <div className="flex h-14 items-center justify-between border-b px-4 pt-safe">
            <h2 className="text-lg font-semibold text-primary">OpenProject</h2>
            <Button variant="ghost" size="icon" onClick={onClose} className="md:hidden">
              <X className="h-5 w-5" />
              <span className="sr-only">Close menu</span>
            </Button>
          </div>

          {/* Navigation */}
          <nav className="flex-1 space-y-1 overflow-y-auto p-4">
            {navItems.map((item) => {
              const isActive = location.pathname === item.href
              const Icon = item.icon

              return (
                <Link
                  key={item.href}
                  to={item.href}
                  onClick={() => {
                    // Close sidebar on mobile after navigation
                    if (window.innerWidth < 768) {
                      onClose()
                    }
                  }}
                  className={cn(
                    'flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors touch-manipulation',
                    isActive
                      ? 'bg-primary text-primary-foreground'
                      : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'
                  )}
                >
                  <Icon className="h-5 w-5" />
                  {item.label}
                </Link>
              )
            })}
          </nav>
        </div>
      </aside>
    </>
  )
}
