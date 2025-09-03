import { Component } from '@angular/core';
import { GridPageComponent } from 'core-app/shared/components/grids/grid/page/grid-page.component';
import { GRID_PROVIDERS } from 'core-app/shared/components/grids/grid/grid.component';

@Component({
  selector: 'dashboard',
  templateUrl: '../../../shared/components/grids/grid/page/grid-page.component.html',
  styleUrls: ['../../../shared/components/grids/grid/page/grid-page.component.sass'],
  providers: GRID_PROVIDERS,
  standalone: false,
})
export class DashboardComponent extends GridPageComponent {
  protected gridScopePath():string {
    return this.pathHelper.projectDashboardsPath(this.currentProject.identifier!);
  }
}
