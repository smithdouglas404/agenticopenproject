import { inject, Injectable, NgZone } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { Board } from 'core-app/features/boards/board/board';
import { BoardService } from 'core-app/features/boards/board/board.service';
import { BoardActionsRegistryService } from 'core-app/features/boards/board/board-actions/board-actions-registry.service';
import { GridWidgetResource } from 'core-app/features/hal/resources/grid-widget-resource';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import { ReactBridge } from 'core-react/bridge/react-bridge';
import { StatusMappingDialog } from 'core-react/components/status-mapping/StatusMappingDialog';
import { ApiV3Filter, FilterOperator } from 'core-app/shared/helpers/api-v3/api-v3-filter-builder';
import type { StatusOption } from 'core-react/components/status-mapping/types';

@Injectable()
export class BoardStatusMappingService {
  private ngZone = inject(NgZone);
  private i18n = inject(I18nService);
  private boardActionRegistry = inject(BoardActionsRegistryService);
  private boardService = inject(BoardService);
  private halNotification = inject(HalResourceNotificationService);

  private text = {
    dialogTitle: this.i18n.t('js.boards.lists.status_mapping.dialog_title'),
    dialogSubtitle: this.i18n.t('js.boards.lists.status_mapping.dialog_subtitle'),
    filterPlaceholder: this.i18n.t('js.boards.lists.status_mapping.filter_placeholder'),
    noSelectionNotice: this.i18n.t('js.boards.lists.status_mapping.no_selection_notice'),
  };

  async openDialog(
    board:Board,
    widget:GridWidgetResource,
    onReload:() => void,
  ):Promise<void> {
    const actionService = this.boardActionRegistry.get('status');

    const allStatuses = await firstValueFrom(
      actionService.loadAvailable(new Set(), ''),
    );

    const availableStatuses:StatusOption[] = allStatuses.map((s:HalResource) => ({
      id: s.id!,
      name: s.name,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any,@typescript-eslint/no-unsafe-member-access
      color: (s as any).color?.hexColor as string | undefined,
    }));

    const existingFilters = (widget.options.filters ?? []) as ApiV3Filter[];
    const statusFilter = existingFilters.find((f) => 'status' in f);
    const currentFilterValues = statusFilter
      ? (statusFilter.status.values as string[]).map((v) => String(v))
      : [];

    const result = await ReactBridge.openDialog<string[]>(StatusMappingDialog, {
      currentFilterValues,
      availableStatuses,
      title: this.text.dialogTitle,
      subtitle: this.text.dialogSubtitle,
      placeholder: this.text.filterPlaceholder,
      noSelectionNotice: this.text.noSelectionNotice,
    });

    if (result) {
      this.ngZone.run(() => {
        const updatedFilters = existingFilters.map((f) => {
          if ('status' in f) {
            return {
              status: {
                operator: '=' as FilterOperator,
                values: result,
              },
            };
          }
          return f;
        });

        widget.options.filters = updatedFilters;

        void firstValueFrom(this.boardService.save(board))
          .then(() => {
            onReload();
          })
          .catch((error) => {
            widget.options.filters = existingFilters;
            this.halNotification.handleRawError(error);
          });
      });
    }
  }

}
