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

import type { Plugin } from 'esbuild';
import * as fs from 'fs';
import * as path from 'path';
import postcss from 'postcss';
import postcssImport from 'postcss-import';
import * as sass from 'sass';

const customConfigPlugin:Plugin = {
  name: 'custom-config',
  setup({ initialOptions: options }) {
    if (options.chunkNames === '[name]-[hash]') { // named chunks
      options.chunkNames = '[dir]/[name]-[hash]';
    }
  }
};

/**
 * esbuild (custom) plugin for importing CSS/SCSS files as raw strings.
 * Enables `import styles from './styles.css?raw'` syntax for use with adoptedStyleSheets.
 *
 * This allows bundling CSS directly into JavaScript for Shadow DOM components,
 * eliminating the need for separate CSS files and avoiding FOUC.
 */
const cssRawPlugin:Plugin = {
  name: 'css-raw',
  setup(build) {
    // Handle imports ending with ?raw (e.g., './styles.css?raw')
    build.onResolve({ filter: /\.(css|scss|sass)\?raw$/ }, args => {
      const importPath = args.path.replace('?raw', '');

      // Resolve the actual file path
      let resolvedPath:string;
      if (importPath.startsWith('.')) {
        // Relative import
        resolvedPath = path.resolve(args.resolveDir, importPath);
      } else {
        // Node modules import - try to resolve
        try {
          resolvedPath = require.resolve(importPath, { paths: [args.resolveDir] });
        } catch {
          // Fallback to node_modules path
          resolvedPath = path.resolve(args.resolveDir, 'node_modules', importPath);
        }
      }

      return {
        path: resolvedPath,
        namespace: 'css-raw',
      };
    });

    build.onLoad({ filter: /.*/, namespace: 'css-raw' }, async args => {
      let css:string;

      if (args.path.endsWith('.scss') || args.path.endsWith('.sass')) {
        // Compile SCSS/Sass to CSS
        const result = sass.compile(args.path, {
          loadPaths: [
            path.dirname(args.path),
            path.resolve(process.cwd(), 'node_modules'),
            path.resolve(process.cwd(), 'src'),
          ],
          silenceDeprecations: ['color-functions', 'global-builtin', 'import', 'mixed-decls'],
        });
        css = result.css;
      } else {
        // Read CSS file directly
        css = await fs.promises.readFile(args.path, 'utf-8');
      }

      // Inline all CSS @import statements using postcss-import
      // Required because adoptedStyleSheets doesn't support @import
      const result = await postcss([postcssImport()]).process(css, { from: args.path });
      css = result.css;

      // Escape backticks and backslashes for template literal
      const escaped = css
        .replace(/\\/g, '\\\\')
        .replace(/`/g, '\\`')
        .replace(/\$/g, '\\$');

      return {
        contents: `export default \`${escaped}\`;`,
        loader: 'js',
      };
    });
  },
};

export default [customConfigPlugin, cssRawPlugin];
