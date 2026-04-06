import { apiFetch } from './client';
import type { QueryResult } from './types';

export async function fetchQuery(
  queryId:string,
  filters?:string,
):Promise<QueryResult> {
  const params = new URLSearchParams();
  params.append('columns[]', 'id');
  params.append('columns[]', 'subject');
  params.set('pageSize', '500');
  params.set('showHierarchies', 'false');

  if (filters) {
    params.set('filters', filters);
  }

  return apiFetch<QueryResult>(`/queries/${queryId}?${params.toString()}`);
}

export async function reorderWorkPackages(
  queryId:string,
  delta:Record<string, number>,
):Promise<{ t:string }> {
  return apiFetch<{ t:string }>(`/queries/${queryId}/order`, {
    method: 'PATCH',
    body: JSON.stringify({ delta }),
  });
}
