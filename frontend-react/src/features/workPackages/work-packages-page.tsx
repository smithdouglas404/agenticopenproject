import { useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Plus, Search, Filter, Calendar, ArrowUpDown } from 'lucide-react'
import { getInitials } from '@/lib/utils'

export function WorkPackagesPage() {
  const [searchQuery, setSearchQuery] = useState('')

  // Mock data - will be replaced with real API calls
  const workPackages = [
    {
      id: 1,
      subject: 'Implement mobile-first navigation',
      status: 'In Progress',
      priority: 'High',
      type: 'Feature',
      assignee: {
        name: 'John Doe',
        avatar: undefined
      },
      project: 'Frontend Redesign',
      dueDate: '2025-11-20',
      percentageDone: 60
    },
    {
      id: 2,
      subject: 'Setup API client integration',
      status: 'New',
      priority: 'Normal',
      type: 'Task',
      assignee: {
        name: 'Jane Smith',
        avatar: undefined
      },
      project: 'Frontend Redesign',
      dueDate: '2025-11-22',
      percentageDone: 0
    },
    {
      id: 3,
      subject: 'Create responsive design system',
      status: 'In Progress',
      priority: 'High',
      type: 'Feature',
      assignee: {
        name: 'John Doe',
        avatar: undefined
      },
      project: 'Frontend Redesign',
      dueDate: '2025-11-18',
      percentageDone: 80
    },
    {
      id: 4,
      subject: 'Fix mobile navigation bug on iOS',
      status: 'New',
      priority: 'High',
      type: 'Bug',
      assignee: {
        name: 'Mike Johnson',
        avatar: undefined
      },
      project: 'Bug Fixes',
      dueDate: '2025-11-17',
      percentageDone: 0
    },
    {
      id: 5,
      subject: 'Update documentation for API endpoints',
      status: 'Resolved',
      priority: 'Low',
      type: 'Documentation',
      assignee: {
        name: 'Sarah Williams',
        avatar: undefined
      },
      project: 'Documentation',
      dueDate: '2025-11-15',
      percentageDone: 100
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
      case 'Resolved':
        return 'success'
      default:
        return 'outline'
    }
  }

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'Bug':
        return 'destructive'
      case 'Feature':
        return 'default'
      case 'Task':
        return 'secondary'
      default:
        return 'outline'
    }
  }

  const filteredWorkPackages = workPackages.filter((wp) =>
    wp.subject.toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <div className="container mx-auto p-4 md:p-6 lg:p-8">
      {/* Header */}
      <div className="mb-6 flex flex-col gap-4">
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <h1 className="text-2xl font-bold tracking-tight md:text-3xl">Work Packages</h1>
            <p className="text-muted-foreground">Manage and track all work packages</p>
          </div>
          <Button size="touch" className="w-full md:w-auto">
            <Plus className="mr-2 h-4 w-4" />
            New Work Package
          </Button>
        </div>

        {/* Search and Filters */}
        <div className="flex flex-col gap-2 md:flex-row">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search work packages..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
          <div className="flex gap-2">
            <Button variant="outline" size="touch" className="flex-1 md:flex-none">
              <Filter className="mr-2 h-4 w-4" />
              Filter
            </Button>
            <Button variant="outline" size="touch" className="flex-1 md:flex-none">
              <ArrowUpDown className="mr-2 h-4 w-4" />
              Sort
            </Button>
          </div>
        </div>
      </div>

      {/* Work Packages List */}
      <div className="space-y-3">
        {filteredWorkPackages.map((wp) => (
          <Card
            key={wp.id}
            className="transition-shadow hover:shadow-md active:shadow-lg touch-manipulation"
          >
            <CardContent className="p-4">
              {/* Mobile-first layout */}
              <div className="space-y-3">
                {/* Title and ID */}
                <div>
                  <div className="flex items-start gap-2">
                    <span className="text-xs font-mono text-muted-foreground">#{wp.id}</span>
                    <h3 className="flex-1 font-medium leading-tight">{wp.subject}</h3>
                  </div>
                </div>

                {/* Badges */}
                <div className="flex flex-wrap gap-2">
                  <Badge variant={getTypeColor(wp.type) as any}>{wp.type}</Badge>
                  <Badge variant={getStatusColor(wp.status) as any}>{wp.status}</Badge>
                  <Badge variant={getPriorityColor(wp.priority) as any}>{wp.priority}</Badge>
                </div>

                {/* Meta information */}
                <div className="flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
                  <div className="flex items-center gap-1.5">
                    <Avatar className="h-5 w-5">
                      <AvatarImage src={wp.assignee.avatar} alt={wp.assignee.name} />
                      <AvatarFallback className="text-xs">
                        {getInitials(wp.assignee.name)}
                      </AvatarFallback>
                    </Avatar>
                    <span className="truncate">{wp.assignee.name}</span>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <Calendar className="h-4 w-4" />
                    <span>{wp.dueDate}</span>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <span className="font-medium">{wp.percentageDone}%</span>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="overflow-hidden rounded-full bg-secondary">
                  <div
                    className="h-1.5 bg-primary transition-all"
                    style={{ width: `${wp.percentageDone}%` }}
                  />
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Empty state */}
      {filteredWorkPackages.length === 0 && (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="text-center">
              <h3 className="mb-2 text-lg font-semibold">No work packages found</h3>
              <p className="mb-4 text-sm text-muted-foreground">
                Try adjusting your search or filters
              </p>
              <Button>Clear filters</Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
