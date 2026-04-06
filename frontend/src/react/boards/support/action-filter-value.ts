import type { ApiV3Filter, QueryFilter } from '../api/types';

function actionFilterNames(actionAttribute:string):string[] {
  if (actionAttribute === 'status') {
    return ['status', 'status_id'];
  }

  return [actionAttribute];
}

export function resolveActionFilterValue(
  filters:QueryFilter[] | undefined,
  actionAttribute:string | undefined,
):string | undefined {
  if (!filters?.length || !actionAttribute) {
    return undefined;
  }

  const filterNames = actionFilterNames(actionAttribute);
  const actionFilter = filters.find((filter:QueryFilter) => {
    const filterHref = filter?._links?.filter?.href ?? '';

    return filterNames.some((name) => filterHref.endsWith(`/filters/${name}`));
  });

  if (!actionFilter) {
    return undefined;
  }

  const values = actionFilter._links.values;
  if (!Array.isArray(values) || values.length === 0) {
    return undefined;
  }

  const href = values[0]?.href ?? '';
  return href.split('/').pop();
}

export function resolveActionWidgetFilterValue(
  filters:ApiV3Filter[] | undefined,
  actionAttribute:string | undefined,
):string | undefined {
  if (!filters?.length || !actionAttribute) {
    return undefined;
  }

  const filterNames = actionFilterNames(actionAttribute);

  for (const filter of filters) {
    for (const name of filterNames) {
      const values = filter[name]?.values;

      if (Array.isArray(values) && values.length > 0) {
        return values[0];
      }
    }
  }

  return undefined;
}
