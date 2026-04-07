import { apiFetch } from './client';
import type { WorkPackage } from './types';

export async function updateWorkPackage(
  wpId:number,
  lockVersion:number,
  attributes:Record<string, unknown>,
):Promise<WorkPackage> {
  return apiFetch<WorkPackage>(`/work_packages/${wpId}`, {
    method: 'PATCH',
    body: JSON.stringify({
      lockVersion,
      ...attributes,
    }),
  });
}
