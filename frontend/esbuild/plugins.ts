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
import { readFile } from 'fs/promises';
import crypto from 'crypto';

const customConfigPlugin:Plugin = {
  name: 'custom-config',
  setup({ initialOptions: options }) {
    if (options.chunkNames === '[name]-[hash]') { // named chunks
      options.chunkNames = '[dir]/[name]-[hash]';
    }
  }
};

const cssModulesPlugin:Plugin = {
  name: 'css-modules',
  setup(build) {
    build.onLoad({ filter: /\.module\.css$/ }, async (args) => {
      const css = await readFile(args.path, 'utf8');
      const classMap:Record<string, string> = {};

      // Generate hash from file path for scoping
      const hash = crypto.createHash('md5')
        .update(args.path)
        .digest('hex')
        .slice(0, 8);

      // Transform .ClassName to .ClassName_hash
      const scopedCss = css.replace(
        /\.([a-zA-Z_][\w-]*)/g,
        (match, className) => {
          const scopedName = `${className}_${hash}`;
          classMap[className] = scopedName;
          return `.${scopedName}`;
        }
      );

      // Return JS that exports class map and injects CSS
      return {
        contents: `
          const style = document.createElement('style');
          style.textContent = ${JSON.stringify(scopedCss)};
          document.head.appendChild(style);
          export default ${JSON.stringify(classMap)};
        `,
        loader: 'js',
      };
    });
  },
};

export default [customConfigPlugin, cssModulesPlugin];
