import { useState } from 'react'
import { Outlet } from 'react-router'
import { MobileNav } from './mobile-nav'
import { BottomNav } from './bottom-nav'
import { Sidebar } from './sidebar'

export function MainLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)

  // Mock user data - will be replaced with real auth
  const user = {
    name: 'John Doe',
    avatar: undefined
  }

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="flex flex-1 flex-col overflow-hidden">
        <MobileNav
          onMenuClick={() => setSidebarOpen(true)}
          notificationCount={3}
          user={user}
        />

        <main className="flex-1 overflow-y-auto pb-16 md:pb-0">
          <Outlet />
        </main>

        <BottomNav />
      </div>
    </div>
  )
}
