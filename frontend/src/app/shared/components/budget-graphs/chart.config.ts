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

import { ChartOptions, TooltipModel } from 'chart.js';
import { html, render } from 'lit-html';

export const chartFont:ChartOptions['font'] = {
  family:
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji'",
  size: 14,
};

export const chartLegend:ChartOptions['plugins'] = {
  legend: {
    position: 'bottom',
    labels: {
      boxWidth: 56,
      boxHeight: 20,
      padding: 16,
      font: { size: 14 },
    },
  },
};

type FormatCurrency = (value:number) => string;

interface TooltipContext<TType extends 'bar' | 'pie'> {
  chart:{ canvas:HTMLCanvasElement };
  tooltip:TooltipModel<TType>;
}

function applyTooltipPosition<TType extends 'bar' | 'pie'>(
  context:TooltipContext<TType>,
  popoverHtml:ReturnType<typeof html>,
  tooltipId:string,
) {
  render(popoverHtml, document.body);

  const tooltipEl = document.getElementById(tooltipId)!;

  if (context.tooltip.opacity === 0) {
    tooltipEl.style.opacity = '0';
    return;
  }

  const position = context.chart.canvas.getBoundingClientRect();

  tooltipEl.style.opacity = '1';
  tooltipEl.style.position = 'absolute';
  tooltipEl.style.left = `${position.left + window.pageXOffset + context.tooltip.caretX}px`;
  tooltipEl.style.top = `${position.top + window.pageYOffset + context.tooltip.caretY}px`;
  tooltipEl.style.pointerEvents = 'none';
}

export function createBarTooltipRenderer(formatCurrency:FormatCurrency) {
  return function(context:TooltipContext<'bar'>) {
    const { tooltip } = context;
    const popoverHtml = html`
      <div class="Popover" id="chartjs-tooltip-bar">
        <div class="Box Popover-message Popover-message--left-top ml-2 mx-auto p-2 text-left text-small">
          <ul class="list-style-none ml-0">
            ${tooltip.dataPoints.map((dp, i) => {
              const timestamp = dp.parsed.x;
              const dateStr = timestamp != null
                ? new Date(timestamp).toLocaleDateString(undefined, { month: 'short', year: 'numeric' })
                : '';
              const label = dp.dataset.label ?? '';
              const value = dp.parsed.y ?? 0;
              const color = tooltip.labelColors[i]?.backgroundColor as string;
              return html`
                <li class="mb-1">
                  <div class="d-flex flex-items-center gap-2">
                    <strong class="text-nowrap">${dateStr}</strong>
                    <span class="flex-shrink-0" style="width: 10px; height: 10px; border-radius: 50%; background: ${color}; display: inline-block"></span>
                    <strong>${label}</strong>
                  </div>
                  <div class="f4" style="font-variant-numeric: tabular-nums">${formatCurrency(value)}</div>
                </li>`;
            })}
          </ul>
        </div>
      </div>`;

    applyTooltipPosition(context, popoverHtml, 'chartjs-tooltip-bar');
  };
}

export function createPieTooltipRenderer(formatCurrency:FormatCurrency) {
  return function(context:TooltipContext<'pie'>) {
    const { tooltip } = context;
    const popoverHtml = html`
      <div class="Popover" id="chartjs-tooltip-pie">
        <div class="Box Popover-message Popover-message--left-top ml-2 mx-auto p-2 text-left text-small">
          <ul class="list-style-none ml-0">
            ${tooltip.dataPoints.map((dp, i) => {
              const color = tooltip.labelColors[i]?.backgroundColor as string;
              const label = dp.label ?? '';
              const value = dp.parsed;
              return html`
                <li class="mb-1">
                  <div class="d-flex flex-items-center gap-2 text-nowrap">
                    <span class="flex-shrink-0" style="width: 10px; height: 10px; border-radius: 50%; background: ${color}; display: inline-block"></span>
                    <strong>${label}</strong>
                  </div>
                  <div class="f4" style="font-variant-numeric: tabular-nums">${formatCurrency(value)}</div>
                </li>`;
            })}
          </ul>
        </div>
      </div>`;

    applyTooltipPosition(context, popoverHtml, 'chartjs-tooltip-pie');
  };
}
