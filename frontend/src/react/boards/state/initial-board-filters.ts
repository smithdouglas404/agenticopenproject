import type { ApiV3Filter } from '../api/types';

export function initialBoardFilters(boardFilters:ApiV3Filter[]):ApiV3Filter[] {
  const params = new URLSearchParams(window.location.search);
  const rawQueryProps = params.get('query_props');

  if (!rawQueryProps) {
    return boardFilters;
  }

  try {
    return JSON.parse(rawQueryProps) as ApiV3Filter[];
  } catch {
    return boardFilters;
  }
}
