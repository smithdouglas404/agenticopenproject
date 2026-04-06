import { useMutation, useQueryClient } from '@tanstack/react-query';
import { reorderWorkPackages } from '../api/queries';

interface ReorderVars {
  queryId:string;
  delta:Record<string, number>;
}

export function useReorderWorkPackages() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ queryId, delta }:ReorderVars) =>
      reorderWorkPackages(queryId, delta),
    onSuccess: (_data, { queryId }) => {
      void queryClient.invalidateQueries({
        queryKey: ['column-work-packages', queryId],
      });
    },
  });
}
