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
 * Type declarations for raw CSS/SCSS imports.
 *
 * These enable importing CSS files as raw strings for use with adoptedStyleSheets:
 *
 *   import styles from './styles.css?raw';
 *   const sheet = new CSSStyleSheet();
 *   sheet.replaceSync(styles);
 *   shadowRoot.adoptedStyleSheets = [sheet];
 *
 * The ?raw suffix is handled by the cssRawPlugin in esbuild/plugins.ts
 */

declare module '*.css?raw' {
  const content:string;
  export default content;
}

declare module '*.scss?raw' {
  const content:string;
  export default content;
}

declare module '*.sass?raw' {
  const content:string;
  export default content;
}
