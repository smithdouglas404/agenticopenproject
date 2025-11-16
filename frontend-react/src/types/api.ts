/**
 * OpenProject API v3 Types
 * Based on HAL+JSON format
 */

export interface HalLink {
  href: string
  title?: string
  method?: string
  templated?: boolean
}

export interface HalLinks {
  self: HalLink
  [key: string]: HalLink | HalLink[] | undefined
}

export interface HalResource {
  _type: string
  _links: HalLinks
  id?: number
  createdAt?: string
  updatedAt?: string
}

export interface HalCollection<T extends HalResource> extends HalResource {
  _embedded: {
    elements: T[]
  }
  total: number
  count: number
  pageSize?: number
  offset?: number
}

// User/Principal Types
export interface User extends HalResource {
  _type: 'User'
  name: string
  firstName?: string
  lastName?: string
  email?: string
  avatar?: string
  status: 'active' | 'locked' | 'registered' | 'invited'
  language?: string
  admin?: boolean
  _links: HalLinks & {
    self: HalLink
    memberships?: HalLink
    showUser?: HalLink
  }
}

// Project Types
export interface Project extends HalResource {
  _type: 'Project'
  identifier: string
  name: string
  description?: {
    format: 'markdown' | 'plain'
    raw: string
    html?: string
  }
  public: boolean
  active: boolean
  statusExplanation?: {
    format: string
    raw: string
    html?: string
  }
  _links: HalLinks & {
    self: HalLink
    parent?: HalLink
    ancestors?: HalLink[]
    workPackages?: HalLink
    categories?: HalLink
    types?: HalLink
    versions?: HalLink
    memberships?: HalLink
  }
}

// Work Package Types
export interface WorkPackageType extends HalResource {
  _type: 'Type'
  name: string
  color: string
  position: number
  isDefault: boolean
  isMilestone: boolean
}

export interface WorkPackageStatusResource extends HalResource {
  _type: 'Status'
  name: string
  isClosed: boolean
  color: string
  isDefault: boolean
  isReadonly: boolean
  defaultDoneRatio?: number
  position: number
}

export interface WorkPackagePriorityResource extends HalResource {
  _type: 'Priority'
  name: string
  position: number
  color: string
  isDefault: boolean
  isActive: boolean
}

export interface WorkPackage extends HalResource {
  _type: 'WorkPackage'
  subject: string
  description?: {
    format: 'markdown' | 'plain'
    raw: string
    html?: string
  }
  scheduleManually: boolean
  readonly: boolean
  startDate?: string | null
  dueDate?: string | null
  estimatedTime?: string | null
  spentTime?: string
  percentageDone: number
  _links: HalLinks & {
    self: HalLink
    project: HalLink
    type: HalLink
    status: HalLink
    priority?: HalLink
    author: HalLink
    assignee?: HalLink
    responsible?: HalLink
    parent?: HalLink
    children?: HalLink[]
    watchers?: HalLink
    attachments?: HalLink
    addAttachment?: HalLink
    update?: HalLink
    delete?: HalLink
    activities?: HalLink
    availableWatchers?: HalLink
  }
  _embedded?: {
    type?: WorkPackageType
    status?: WorkPackageStatusResource
    priority?: WorkPackagePriorityResource
    project?: Project
    author?: User
    assignee?: User
    responsible?: User
  }
}

// Query Types
export interface Query extends HalResource {
  _type: 'Query'
  name: string
  filters?: any[]
  sums?: boolean
  public: boolean
  starred?: boolean
  _links: HalLinks & {
    self: HalLink
    user?: HalLink
    project?: HalLink
    results?: HalLink
  }
}

// Notification Types
export interface Notification extends HalResource {
  _type: 'Notification'
  reason: string
  readIAN: boolean
  readEmail?: boolean
  details?: any[]
  _links: HalLinks & {
    self: HalLink
    project?: HalLink
    actor?: HalLink
    resource?: HalLink
    readIAN?: HalLink
    unreadIAN?: HalLink
  }
}

// API Error Types
export interface ApiError {
  _type: 'Error'
  errorIdentifier: string
  message: string
  details?: {
    attribute: string
    message: string
  }[]
}

// Pagination Parameters
export interface PaginationParams {
  offset?: number
  pageSize?: number
}

// Filter Parameters
export interface FilterParams {
  filters?: string
  sortBy?: string
  groupBy?: string
}

// API Response Types
export type ApiResponse<T> = T
export type ApiCollectionResponse<T extends HalResource> = HalCollection<T>
