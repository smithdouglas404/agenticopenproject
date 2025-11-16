import { toast as sonnerToast } from 'sonner'

/**
 * Hook for showing toast notifications
 * Wraps Sonner toast library with a consistent API
 */
export function useToast() {
  return {
    success: (message: string, description?: string) => {
      sonnerToast.success(message, { description })
    },
    error: (message: string, description?: string) => {
      sonnerToast.error(message, { description })
    },
    info: (message: string, description?: string) => {
      sonnerToast.info(message, { description })
    },
    warning: (message: string, description?: string) => {
      sonnerToast.warning(message, { description })
    },
    loading: (message: string, description?: string) => {
      return sonnerToast.loading(message, { description })
    },
    dismiss: (id?: string | number) => {
      if (id) {
        sonnerToast.dismiss(id)
      } else {
        sonnerToast.dismiss()
      }
    }
  }
}
