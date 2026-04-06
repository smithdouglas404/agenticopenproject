import type { QueryOrder } from 'core-app/core/apiv3/endpoints/queries/apiv3-query-order';

/** Minimal HAL link. */
export interface HalLink {
  href:string;
  method?:string;
}

/** Minimal HAL resource with self link. */
export interface HalResource {
  _type?:string;
  _links:{
    self:HalLink;
    [key:string]:HalLink | HalLink[] | undefined;
  };
}

/** HAL collection envelope. */
export interface HalCollection<T> {
  _type:string;
  count:number;
  total:number;
  _embedded:{ elements:T[] };
}

export interface GridWidget {
  _type:'GridWidget';
  identifier:string;
  startRow:number;
  endRow:number;
  startColumn:number;
  endColumn:number;
  options:{
    queryId?:string | number;
    filters?:ApiV3Filter[];
    [key:string]:unknown;
  };
}

export interface BoardGrid extends HalResource {
  id:number;
  name:string;
  rowCount:number;
  columnCount:number;
  widgets:GridWidget[];
  options:{
    type:'free' | 'action';
    attribute?:string;
    highlightingMode?:string;
    filters?:ApiV3Filter[];
  };
  _links:HalResource['_links'] & {
    delete?:HalLink;
    update?:HalLink;
    updateImmediately?:HalLink;
  };
}

export interface ApiV3FilterValue {
  operator:string;
  values:string[];
}

export type ApiV3Filter = Record<string, ApiV3FilterValue>;

export interface QueryColumn {
  id:string;
  name:string;
  _type:string;
}

export interface QueryFilter extends HalResource {
  _links:HalResource['_links'] & {
    filter?:HalLink;
    values?:HalLink[];
  };
}

export interface WorkPackage extends HalResource {
  id:number;
  subject:string;
  lockVersion:number;
  _links:HalResource['_links'] & {
    type:HalLink & { title:string };
    status:HalLink & { title:string };
    priority:HalLink & { title:string };
    assignee?:HalLink & { title:string };
    project:HalLink & { title:string };
  };
}

export interface QueryResult extends HalResource {
  id:number;
  name:string;
  filters:QueryFilter[];
  columns:QueryColumn[];
  _embedded:{
    results:HalCollection<WorkPackage>;
  };
  ordered_work_packages?:QueryOrder;
  _links:HalResource['_links'] & {
    updateOrderedWorkPackages?:HalLink;
  };
}

export interface Status extends HalResource {
  id:number;
  name:string;
  color:string;
  isDefault:boolean;
  isClosed:boolean;
  position:number;
}
