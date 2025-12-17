/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

/**
 * Shared stylesheets for Shadow DOM components.
 *
 * These use constructable stylesheets (adoptedStyleSheets) which:
 * - Parse CSS once and share across all Shadow DOM instances (memory efficient)
 * - Apply styles synchronously (no FOUC)
 * - Don't require separate CSS file downloads
 *
 * Usage:
 *   import { primerStyleSheet } from './shadow-dom-styles';
 *   shadowRoot.adoptedStyleSheets = [primerStyleSheet];
 */

// Import Primer styles as raw CSS string (compiled from SCSS at build time)
import primerStyles from '../global_styles/vendor/_primer.sass?raw';

// Create shared constructable stylesheet for Primer
// This is parsed once and shared across all Shadow DOM instances
const primerStyleSheet = new CSSStyleSheet();
primerStyleSheet.replaceSync(primerStyles);

export { primerStyleSheet };
