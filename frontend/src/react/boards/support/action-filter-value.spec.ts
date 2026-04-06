import type { ApiV3Filter, QueryFilter } from '../api/types';
import {
  resolveActionFilterValue,
  resolveActionWidgetFilterValue,
} from './action-filter-value';

describe('resolveActionFilterValue', () => {
  it('resolves status board filters from status_id', () => {
    const filters = [
      {
        _links: {
          self: { href: '/api/v3/queries/1/filters/1' },
          filter: { href: '/api/v3/queries/filters/status_id' },
          values: [{ href: '/api/v3/statuses/12' }],
        },
      },
    ] as QueryFilter[];

    expect(resolveActionFilterValue(filters, 'status')).toBe('12');
  });

  it('resolves action filters from their direct attribute name', () => {
    const filters = [
      {
        _links: {
          self: { href: '/api/v3/queries/1/filters/1' },
          filter: { href: '/api/v3/queries/filters/version' },
          values: [{ href: '/api/v3/versions/7' }],
        },
      },
    ] as QueryFilter[];

    expect(resolveActionFilterValue(filters, 'version')).toBe('7');
  });

  it('returns undefined when the action filter is absent', () => {
    expect(resolveActionFilterValue([], 'status')).toBeUndefined();
  });
});

describe('resolveActionWidgetFilterValue', () => {
  it('resolves status board filters from widget status_id filters', () => {
    const filters:ApiV3Filter[] = [
      {
        status_id: {
          operator: '=',
          values: ['12'],
        },
      },
    ];

    expect(resolveActionWidgetFilterValue(filters, 'status')).toBe('12');
  });

  it('resolves action filters from widget filters by direct attribute name', () => {
    const filters:ApiV3Filter[] = [
      {
        version: {
          operator: '=',
          values: ['7'],
        },
      },
    ];

    expect(resolveActionWidgetFilterValue(filters, 'version')).toBe('7');
  });

  it('returns undefined when the widget action filter is absent', () => {
    expect(resolveActionWidgetFilterValue([], 'status')).toBeUndefined();
  });
});
