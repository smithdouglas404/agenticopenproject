//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  ChangeDetectionStrategy,
  Component,
  Signal,
  computed,
  input,
} from '@angular/core';
import { ChartConfiguration, ChartData } from 'chart.js';
import 'chartjs-adapter-luxon';
import { NoResultsComponent } from 'core-app/shared/components/blankslate/no-results.component';
import { chartFont, chartLegend, renderChartTooltip } from 'core-app/shared/components/budget-graphs/chart.config';
import PrimerColorsPlugin from 'core-app/shared/components/work-package-graphs/plugin.primer-colors';
import { BaseChartDirective, provideCharts, withDefaultRegisterables } from 'ng2-charts';

@Component({
  selector: 'opce-actual-costs',
  templateUrl: './actual-costs.component.html',
  imports: [BaseChartDirective, NoResultsComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [provideCharts(withDefaultRegisterables(PrimerColorsPlugin))],
})
export class ActualCostsComponent {
  readonly chartData = input.required<string>();
  readonly currency = input<string>('EUR');

  readonly barChartData = computed<ChartData<'bar'>>(() => JSON.parse(this.chartData()) as ChartData<'bar'>);
  readonly hasChartData = computed(() => this.barChartData().datasets.length > 0);

  readonly barChartOptions:Signal<ChartConfiguration<'bar'>['options']> = computed<ChartConfiguration<'bar'>['options']>(() => ({
    font: chartFont,
    aspectRatio: 1.5,
    scales: {
      x: {
        stacked: true,
        type: 'time',
        time: {
          unit: 'month',
        },
      },
      y: {
        stacked: true,
        ticks: {
          callback: (value) => this.formatCurrencyCompact(value as number),
        },
      },
    },
    plugins: {
      ...chartLegend,
      tooltip: {
        enabled: false,
        external: renderChartTooltip,
        callbacks: {
          title: (context) => {
            const timestamp = context[0].parsed.x;
            if (timestamp === null) return '';
            const date = new Date(timestamp);
            return date.toLocaleDateString(undefined, {
              month: 'short',
              year: 'numeric',
            });
          },
          label: (context) => {
            const label = context.dataset.label ?? '';
            const value = context.raw as number;
            return `${label}: ${this.formatCurrency(value)}`;
          },
        },
      },
    },
  }));

  private formatCurrencyCompact(value:number):string {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: this.currency(),
      notation: 'compact',
      compactDisplay: 'short',
      maximumFractionDigits: 1,
    }).format(value);
  }

  private formatCurrency(value:number):string {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: this.currency(),
      maximumFractionDigits: 0,
    }).format(value);
  }
}
