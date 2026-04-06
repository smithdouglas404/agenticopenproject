import { useQuery } from '@tanstack/react-query';
import { fetchQuery } from '../api/queries';
import type { ApiV3Filter, QueryResult } from '../api/types';

export function useColumnWorkPackages(
  queryId:string,
  boardFilters?:ApiV3Filter[],
  widgetFilters?:ApiV3Filter[],
) {
  const mergedFilters = [
    ...(boardFilters ?? []),
    ...(widgetFilters ?? []),
  ];

  const filtersParam = mergedFilters.length > 0
    ? JSON.stringify(mergedFilters)
    : undefined;

  return useQuery<QueryResult>({
    queryKey: ['column-work-packages', queryId, filtersParam],
    queryFn: () => fetchQuery(queryId, filtersParam),
    refetchInterval: 10_000,
  });
}
