import { apiFetch } from './client';
import type { HalCollection, Status } from './types';

export async function fetchStatuses(): Promise<Status[]> {
  const result = await apiFetch<HalCollection<Status>>('/statuses');
  return result._embedded.elements;
}
