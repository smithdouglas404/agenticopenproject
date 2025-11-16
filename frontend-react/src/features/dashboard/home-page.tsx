import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Plus, TrendingUp, Clock, CheckCircle2 } from 'lucide-react'

export function HomePage() {
  // Mock data - will be replaced with real API calls
  const stats = [
    {
      label: 'Active Tasks',
      value: 12,
      icon: Clock,
      trend: '+2 this week',
      color: 'text-blue-600'
    },
    {
      label: 'Completed',
      value: 28,
      icon: CheckCircle2,
      trend: '+8 this week',
      color: 'text-green-600'
    },
    {
      label: 'Progress',
      value: '67%',
      icon: TrendingUp,
      trend: '+12% from last week',
      color: 'text-purple-600'
    }
  ]

  const recentWorkPackages = [
    {
      id: 1,
      subject: 'Implement mobile-first navigation',
      status: 'In Progress',
      priority: 'High',
      assignee: 'John Doe',
      dueDate: '2025-11-20'
    },
    {
      id: 2,
      subject: 'Setup API client integration',
      status: 'New',
      priority: 'Normal',
      assignee: 'Jane Smith',
      dueDate: '2025-11-22'
    },
    {
      id: 3,
      subject: 'Create responsive design system',
      status: 'In Progress',
      priority: 'High',
      assignee: 'John Doe',
      dueDate: '2025-11-18'
    }
  ]

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'High':
        return 'destructive'
      case 'Normal':
        return 'secondary'
      case 'Low':
        return 'outline'
      default:
        return 'default'
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'In Progress':
        return 'default'
      case 'New':
        return 'secondary'
      case 'Completed':
        return 'success'
      default:
        return 'outline'
    }
  }

  return (
    <div className="container mx-auto p-4 md:p-6 lg:p-8">
      {/* Header */}
      <div className="mb-6 flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight md:text-3xl">Dashboard</h1>
          <p className="text-muted-foreground">Welcome back! Here's what's happening.</p>
        </div>
        <Button size="touch" className="w-full md:w-auto">
          <Plus className="mr-2 h-4 w-4" />
          New Work Package
        </Button>
      </div>

      {/* Stats Grid */}
      <div className="mb-6 grid gap-4 md:grid-cols-3">
        {stats.map((stat) => {
          const Icon = stat.icon
          return (
            <Card key={stat.label}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{stat.label}</CardTitle>
                <Icon className={`h-4 w-4 ${stat.color}`} />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
                <p className="text-xs text-muted-foreground">{stat.trend}</p>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Recent Work Packages */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Work Packages</CardTitle>
          <CardDescription>Your most recently updated work packages</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {recentWorkPackages.map((wp) => (
              <div
                key={wp.id}
                className="flex flex-col gap-2 rounded-lg border p-4 transition-colors hover:bg-accent md:flex-row md:items-center md:justify-between"
              >
                <div className="flex-1 space-y-1">
                  <p className="font-medium leading-none">{wp.subject}</p>
                  <div className="flex flex-wrap gap-2 text-sm text-muted-foreground">
                    <span>#{wp.id}</span>
                    <span>•</span>
                    <span>{wp.assignee}</span>
                    <span>•</span>
                    <span>Due {wp.dueDate}</span>
                  </div>
                </div>
                <div className="flex gap-2">
                  <Badge variant={getStatusColor(wp.status) as any}>{wp.status}</Badge>
                  <Badge variant={getPriorityColor(wp.priority) as any}>{wp.priority}</Badge>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
