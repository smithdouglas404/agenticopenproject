import { initialBoardFilters } from './initial-board-filters';
import type { ApiV3Filter } from '../api/types';

describe('initialBoardFilters', () => {
  const boardFilters:ApiV3Filter[] = [
    { status: { operator: '=', values: ['1', '2'] } },
  ];

  afterEach(() => {
    window.history.pushState({}, '', '/');
  });

  it('uses board options filters when query_props is absent', () => {
    expect(initialBoardFilters(boardFilters)).toEqual(boardFilters);
  });

  it('uses query_props from the URL when present', () => {
    const queryProps = [{ search: { operator: '**', values: ['Task'] } }];

    window.history.pushState(
      {},
      '',
      `/projects/demo/boards/123?query_props=${encodeURIComponent(JSON.stringify(queryProps))}`,
    );

    expect(initialBoardFilters(boardFilters)).toEqual(queryProps);
  });

  it('ignores invalid query_props and falls back to board filters', () => {
    window.history.pushState({}, '', '/projects/demo/boards/123?query_props=%5B');

    expect(initialBoardFilters(boardFilters)).toEqual(boardFilters);
  });
});
