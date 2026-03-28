import { useMutation, useQueryClient } from '@tanstack/react-query';
import { updateWorkPackage } from '../api/work-packages';

interface UpdateWorkPackageVars {
  wpId: number;
  lockVersion: number;
  attributes: Record<string, unknown>;
  sourceQueryId: string;
  targetQueryId: string;
}

export function useUpdateWorkPackage() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ wpId, lockVersion, attributes }: UpdateWorkPackageVars) =>
      updateWorkPackage(wpId, lockVersion, attributes),
    onSuccess: (_data, { sourceQueryId, targetQueryId }) => {
      queryClient.invalidateQueries({
        queryKey: ['column-work-packages', sourceQueryId],
      });
      queryClient.invalidateQueries({
        queryKey: ['column-work-packages', targetQueryId],
      });
    },
  });
}
