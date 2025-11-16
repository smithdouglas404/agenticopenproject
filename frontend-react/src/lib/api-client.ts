import axios, { AxiosInstance, AxiosRequestConfig, AxiosError } from 'axios'
import type {
  ApiCollectionResponse,
  ApiError,
  ApiResponse,
  FilterParams,
  PaginationParams,
  Project,
  User,
  WorkPackage,
  Notification,
  Query
} from '@/types/api'

/**
 * OpenProject API v3 Client
 * Implements HAL+JSON API communication
 */
class ApiClient {
  private client: AxiosInstance

  constructor(baseURL: string = '/api/v3') {
    this.client = axios.create({
      baseURL,
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/hal+json'
      },
      withCredentials: true
    })

    this.setupInterceptors()
  }

  private setupInterceptors() {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        // Add CSRF token if available
        const csrfToken = this.getCSRFToken()
        if (csrfToken) {
          config.headers['X-CSRF-Token'] = csrfToken
        }
        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError<ApiError>) => {
        if (error.response?.status === 401) {
          // Handle unauthorized - redirect to login
          window.location.href = '/login'
        }
        return Promise.reject(this.normalizeError(error))
      }
    )
  }

  private getCSRFToken(): string | null {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta?.getAttribute('content') || null
  }

  private normalizeError(error: AxiosError<ApiError>): Error {
    if (error.response?.data) {
      const apiError = error.response.data
      const message = apiError.message || 'An error occurred'
      const err = new Error(message)
      ;(err as any).details = apiError.details
      ;(err as any).identifier = apiError.errorIdentifier
      return err
    }
    return error
  }

  private buildQueryString(params: FilterParams & PaginationParams): string {
    const queryParams = new URLSearchParams()

    if (params.offset !== undefined) {
      queryParams.set('offset', params.offset.toString())
    }
    if (params.pageSize !== undefined) {
      queryParams.set('pageSize', params.pageSize.toString())
    }
    if (params.filters) {
      queryParams.set('filters', params.filters)
    }
    if (params.sortBy) {
      queryParams.set('sortBy', params.sortBy)
    }
    if (params.groupBy) {
      queryParams.set('groupBy', params.groupBy)
    }

    const str = queryParams.toString()
    return str ? `?${str}` : ''
  }

  // Generic request methods
  async get<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const response = await this.client.get<T>(url, config)
    return response.data
  }

  async post<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const response = await this.client.post<T>(url, data, config)
    return response.data
  }

  async patch<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const response = await this.client.patch<T>(url, data, config)
    return response.data
  }

  async delete<T = any>(url: string, config?: AxiosRequestConfig): Promise<ApiResponse<T>> {
    const response = await this.client.delete<T>(url, config)
    return response.data
  }

  // User/Authentication endpoints
  auth = {
    getCurrentUser: () => this.get<User>('/users/me'),

    getUser: (id: number) => this.get<User>(`/users/${id}`)
  }

  // Project endpoints
  projects = {
    list: (params: FilterParams & PaginationParams = {}) =>
      this.get<ApiCollectionResponse<Project>>(`/projects${this.buildQueryString(params)}`),

    get: (id: number | string) => this.get<Project>(`/projects/${id}`),

    create: (data: Partial<Project>) => this.post<Project>('/projects', data),

    update: (id: number | string, data: Partial<Project>) =>
      this.patch<Project>(`/projects/${id}`, data),

    delete: (id: number | string) => this.delete(`/projects/${id}`)
  }

  // Work Package endpoints
  workPackages = {
    list: (params: FilterParams & PaginationParams = {}) =>
      this.get<ApiCollectionResponse<WorkPackage>>(
        `/work_packages${this.buildQueryString(params)}`
      ),

    get: (id: number, params?: { timestamps?: string[] }) => {
      const queryString = params?.timestamps
        ? `?timestamps=${params.timestamps.join(',')}`
        : ''
      return this.get<WorkPackage>(`/work_packages/${id}${queryString}`)
    },

    create: (data: Partial<WorkPackage>) => this.post<WorkPackage>('/work_packages', data),

    update: (id: number, data: Partial<WorkPackage>, lockVersion?: number) => {
      const payload = lockVersion ? { ...data, lockVersion } : data
      return this.patch<WorkPackage>(`/work_packages/${id}`, payload)
    },

    delete: (id: number) => this.delete(`/work_packages/${id}`),

    listByProject: (projectId: number | string, params: FilterParams & PaginationParams = {}) =>
      this.get<ApiCollectionResponse<WorkPackage>>(
        `/projects/${projectId}/work_packages${this.buildQueryString(params)}`
      )
  }

  // Query endpoints
  queries = {
    list: (params: FilterParams & PaginationParams = {}) =>
      this.get<ApiCollectionResponse<Query>>(`/queries${this.buildQueryString(params)}`),

    get: (id: number) => this.get<Query>(`/queries/${id}`),

    create: (data: Partial<Query>) => this.post<Query>('/queries', data),

    update: (id: number, data: Partial<Query>) => this.patch<Query>(`/queries/${id}`, data),

    delete: (id: number) => this.delete(`/queries/${id}`),

    star: (id: number) => this.patch(`/queries/${id}/star`),

    unstar: (id: number) => this.patch(`/queries/${id}/unstar`)
  }

  // Notification endpoints
  notifications = {
    list: (params: FilterParams & PaginationParams = {}) =>
      this.get<ApiCollectionResponse<Notification>>(
        `/notifications${this.buildQueryString(params)}`
      ),

    get: (id: number) => this.get<Notification>(`/notifications/${id}`),

    markAsRead: (id: number) => this.post(`/notifications/${id}/read_ian`),

    markAsUnread: (id: number) => this.post(`/notifications/${id}/unread_ian`),

    markAllAsRead: () => this.post('/notifications/read_ian')
  }

  // Attachment endpoints
  attachments = {
    upload: (file: File, metadata?: any) => {
      const formData = new FormData()
      formData.append('file', file)
      if (metadata) {
        formData.append('metadata', JSON.stringify(metadata))
      }
      return this.post('/attachments', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })
    },

    get: (id: number) => this.get(`/attachments/${id}`),

    delete: (id: number) => this.delete(`/attachments/${id}`)
  }

  // Activity/Timeline endpoints
  activities = {
    listForWorkPackage: (wpId: number, params: PaginationParams = {}) =>
      this.get<ApiCollectionResponse<any>>(
        `/work_packages/${wpId}/activities${this.buildQueryString(params)}`
      )
  }
}

// Export singleton instance
export const apiClient = new ApiClient()

// Export class for testing
export { ApiClient }
