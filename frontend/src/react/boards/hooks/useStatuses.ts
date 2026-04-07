import { useQuery } from '@tanstack/react-query';
import { fetchStatuses } from '../api/statuses';
import type { Status } from '../api/types';

export function useStatuses() {
  return useQuery<Status[]>({
    queryKey: ['statuses'],
    queryFn: fetchStatuses,
    staleTime: 60_000,
  });
}
