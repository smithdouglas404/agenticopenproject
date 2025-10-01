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

// Based on https://github.com/chartjs/Chart.js/blob/master/src/plugins/plugin.colors.ts

import {
  BarController,
  Chart,
  ChartDataset,
  ChartType,
  DoughnutController,
  Plugin,
  PolarAreaController
} from 'chart.js';

export interface PrimerColorsPluginOptions {
  enabled?:boolean;
}

const PRIMER_COLORS = [
  'teal',   // (fresh contrast)
  'orange', // (bold, warm → most eye-catching → first)
  'green',  // (contrasts strongly with orange)
  'purple', // (cool, distinct)
  'red',    // (strong, but not first to avoid clash with orange)
  'yellow', // (bright highlight, works better later)
  'blue',   // (strong primary)
  'pink',   // (vivid, contrasts with blue)
  'pine',   // (deep green, darker balance)
  'auburn', // (earthy tone)
  'brown',  // (neutral balance)
  'cyan',   // (slight highlight between neutral colours)
  'gray',   // (neutral, mid-series filler)
  'lemon',  // (darker yellow, less eye-catching)
  'olive',  // (subdued green, background tone)
  'lime',   // (subdued green, good closing color)
];

function getCSSVariable(variable:string) {
  return getComputedStyle(document.body).getPropertyValue(variable).trim();
}

const EMPHASIS_COLORS = PRIMER_COLORS
  .map((color) => getCSSVariable(`--display-${color}-scale-4`));

const MUTED_COLORS = PRIMER_COLORS
  .map((color) => getCSSVariable(`--display-${color}-scale-1`));

function getEmphasisColor(i:number) {
  return EMPHASIS_COLORS[i % EMPHASIS_COLORS.length];
}

function getMutedColor(i:number) {
  return MUTED_COLORS[i % MUTED_COLORS.length];
}

function colorizeDefaultDataset(dataset:ChartDataset, i:number) {
  dataset.borderColor = getEmphasisColor(i);
  dataset.backgroundColor = getMutedColor(i);

  return ++i;
}

function colorizeBarDataset(dataset:ChartDataset, i:number) {
  dataset.backgroundColor = dataset.data.map(() => getEmphasisColor(i++));

  return i;
}

function colorizeDoughnutDataset(dataset:ChartDataset, i:number) {
  dataset.backgroundColor = dataset.data.map(() => getEmphasisColor(i++));

  return i;
}

function colorizePolarAreaDataset(dataset:ChartDataset, i:number) {
  dataset.backgroundColor = dataset.data.map(() => getMutedColor(i++));

  return i;
}

function getColorizer(chart:Chart) {
  let i = 0;

  return (dataset:ChartDataset, datasetIndex:number) => {
    const controller = chart.getDatasetMeta(datasetIndex).controller;

    if (controller instanceof DoughnutController) {
      i = colorizeDoughnutDataset(dataset, i);
    } else if (controller instanceof PolarAreaController) {
      i = colorizePolarAreaDataset(dataset, i);
    } else if (controller instanceof BarController) {
      i = colorizeBarDataset(dataset, i);
    } else {
      i = colorizeDefaultDataset(dataset, i);
    }
  };
}

const plugin:Plugin<ChartType, PrimerColorsPluginOptions> = {
  id: 'primer-colors',
  defaults: { enabled: true },

  beforeLayout(chart, _args, options) {
    if (!options.enabled) {
      return;
    }

    const { data: { datasets } } = chart.config;
    const colorizer = getColorizer(chart);

    datasets.forEach(colorizer);
  },
};

export default plugin;
