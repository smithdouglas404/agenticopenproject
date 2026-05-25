import { input } from '@openproject/reactivestates';
import { Injectable } from '@angular/core';
import { ApiV3Filter } from 'core-app/shared/helpers/api-v3/api-v3-filter-builder';

@Injectable()
export class BoardFiltersService {
  /**
   * We need to remember the current filter, that may either come
   * from the saved board, or were assigned by the user.
   *
   * This is due to the fact we do not work on an query object here.
   */
  filters = input<ApiV3Filter[]>([]);

  /**
   * Persistable filter set (without temporary quick filters).
   */
  persistedFilters = input<ApiV3Filter[]>([]);

  /**
   * Temporary quick filters that only affect the current board session.
   */
  temporaryFilters = input<ApiV3Filter[]>([]);

  /**
   * Baseline persisted filters loaded from the board itself.
   */
  baselinePersistedFilters = input<ApiV3Filter[]>([]);

  get current():ApiV3Filter[] {
    return this.filters.getValueOr([]);
  }

  get persisted():ApiV3Filter[] {
    return this.persistedFilters.getValueOr([]);
  }

  get hasPersistedChanges():boolean {
    return !_.isEqual(this.persisted, this.baselinePersistedFilters.getValueOr([]));
  }

  initialize(filters:ApiV3Filter[]|undefined|null, baselinePersistedFilters:ApiV3Filter[]|undefined|null = filters) {
    const normalizedPersistedFilters = this.normalizeFilters(filters);
    const normalizedBaseline = this.normalizeFilters(baselinePersistedFilters);

    this.persistedFilters.putValue(normalizedPersistedFilters);
    this.temporaryFilters.putValue([]);
    this.filters.putValue(this.mergeFilters(normalizedPersistedFilters, []));
    this.baselinePersistedFilters.putValue(normalizedBaseline);
  }

  updatePersisted(filters:ApiV3Filter[]|undefined|null) {
    const normalizedPersistedFilters = this.normalizeFilters(filters);

    this.persistedFilters.putValue(normalizedPersistedFilters);
    this.filters.putValue(this.mergeFilters(normalizedPersistedFilters, this.temporaryFilters.getValueOr([])));
  }

  setTemporary(filterName:string, filter:ApiV3Filter|undefined|null) {
    const temporaryFilters = this
      .normalizeFilters(this.temporaryFilters.getValueOr([]))
      .filter((existingFilter) => this.filterKey(existingFilter) !== filterName);

    if (filter) {
      temporaryFilters.push(filter);
    }

    this.temporaryFilters.putValue(temporaryFilters);
    this.filters.putValue(this.mergeFilters(this.persisted, temporaryFilters));
  }

  markPersistedAsSaved() {
    this.baselinePersistedFilters.putValue(this.persisted);
  }

  private normalizeFilters(filters:ApiV3Filter[]|undefined|null):ApiV3Filter[] {
    return Array.isArray(filters) ? filters : [];
  }

  private mergeFilters(persistedFilters:ApiV3Filter[], temporaryFilters:ApiV3Filter[]):ApiV3Filter[] {
    const overriddenFilters = new Set<string>(temporaryFilters.map((filter) => this.filterKey(filter)));

    return persistedFilters
      .filter((filter) => !overriddenFilters.has(this.filterKey(filter)))
      .concat(temporaryFilters);
  }

  private filterKey(filter:ApiV3Filter):string {
    return Object.keys(filter)[0] || '';
  }
}
