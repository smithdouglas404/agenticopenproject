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
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unsafe-assignment */

import TruncationController from './truncation.controller';
import { setupStimulusTest, type StimulusTestContext } from 'core-stimulus/test-helpers';

const horizontalTemplate = `
  <div data-controller="truncation" data-truncation-expanded-value="false" data-truncation-mode-value="horizontal" data-truncation-inline-value="true">
    <div data-truncation-target="truncate" style="width: 200px; overflow: hidden;">
      <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
        This is a very long text that should be truncated when it exceeds the container width
      </span>
    </div>
    <div data-truncation-target="expander">
      <button type="button">Toggle</button>
    </div>
  </div>
`;

const verticalTemplate = `
  <div data-controller="truncation" data-truncation-expanded-value="false" data-truncation-mode-value="vertical" data-truncation-inline-value="true">
    <div data-truncation-target="truncate" class="line-clamp-3" style="overflow: hidden;">
      <p>Line one of a multi-line block of text.</p>
      <p>Line two with more content.</p>
      <p>Line three extends beyond the clamp limit.</p>
      <p>Line four is hidden by the clamp.</p>
    </div>
    <div data-truncation-target="expander">
      <button type="button">Toggle</button>
    </div>
  </div>
`;

const dialogTemplate = `
  <div data-controller="truncation" data-truncation-expanded-value="false" data-truncation-mode-value="vertical" data-truncation-inline-value="false">
    <div data-truncation-target="truncate" class="line-clamp-3" style="overflow: hidden;">
      <p>Content that opens in a dialog.</p>
    </div>
    <div data-truncation-target="expander">
      <button type="button" data-show-dialog-id="my-dialog">Toggle</button>
    </div>
  </div>
`;

describe('TruncationController', () => {
  let ctx:StimulusTestContext;
  let originalI18n:any;

  beforeEach(() => {
    originalI18n = (window as any).I18n;
    if (originalI18n && typeof originalI18n.store === 'function') {
      originalI18n.store({
        en: {
          js: {
            label_expand_text: 'Expand text',
            label_collapse_text: 'Collapse text',
          },
        },
      });
    }
  });

  beforeEach(async () => {
    ctx = await setupStimulusTest({
      controllers: { truncation: TruncationController },
    });
  });

  afterEach(() => {
    try {
      ctx.dispose();
    } finally {
      if (originalI18n) {
        (window as any).I18n = originalI18n;
      }
    }
  });

  describe('horizontal mode', () => {
    describe('initialization', () => {
      beforeEach(async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();
      });

      it('connects successfully', () => {
        const controller = ctx.getController('truncation');

        expect(controller).toBeDefined();
      });

      it('sets initial aria attributes on expander button', () => {
        const button = ctx.screen.getByRole('button', { name: 'Expand text', hidden: true });

        expect(button).toHaveAttribute('aria-expanded', 'false');
      });

      it('adds Truncate--expanded class when expanded value is true', async () => {
        const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

        expect(truncateEl).not.toHaveClass('Truncate--expanded');

        const controller = ctx.getController<TruncationController>('truncation');

        controller.expandedValue = true;
        await ctx.nextFrame();

        expect(truncateEl).toHaveClass('Truncate--expanded');
      });
    });

    describe('expander button click', () => {
      beforeEach(async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();
      });

      it('toggles expanded state', async () => {
        const button = ctx.screen.getByRole('button', { name: 'Expand text', hidden: true });
        const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

        expect(truncateEl).not.toHaveClass('Truncate--expanded');
        expect(button).toHaveAttribute('aria-expanded', 'false');

        button.click();
        await ctx.nextFrame();

        expect(truncateEl).toHaveClass('Truncate--expanded');
        expect(button).toHaveAttribute('aria-expanded', 'true');
        expect(button).toHaveAttribute('aria-label', 'Collapse text');

        button.click();
        await ctx.nextFrame();

        expect(truncateEl).not.toHaveClass('Truncate--expanded');
        expect(button).toHaveAttribute('aria-expanded', 'false');
        expect(button).toHaveAttribute('aria-label', 'Expand text');
      });
    });

    describe('expandedValue changes', () => {
      beforeEach(async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();
      });

      it('updates aria-label when expanded', async () => {
        const button = ctx.screen.getByRole('button', { name: 'Expand text', hidden: true });
        const controller = ctx.getController<TruncationController>('truncation');

        expect(button).toHaveAttribute('aria-label', 'Expand text');

        controller.expandedValue = true;
        await ctx.nextFrame();

        expect(button).toHaveAttribute('aria-label', 'Collapse text');
      });

      it('updates aria-expanded attribute', async () => {
        const button = ctx.screen.getByRole('button', { name: 'Expand text', hidden: true });
        const controller = ctx.getController<TruncationController>('truncation');

        expect(button).toHaveAttribute('aria-expanded', 'false');

        controller.expandedValue = true;
        await ctx.nextFrame();

        expect(button).toHaveAttribute('aria-expanded', 'true');
      });

      it('toggles Truncate--expanded class', async () => {
        const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
        const controller = ctx.getController<TruncationController>('truncation');

        expect(truncateEl).not.toHaveClass('Truncate--expanded');

        controller.expandedValue = true;
        await ctx.nextFrame();

        expect(truncateEl).toHaveClass('Truncate--expanded');

        controller.expandedValue = false;
        await ctx.nextFrame();

        expect(truncateEl).not.toHaveClass('Truncate--expanded');
      });
    });

    describe('expander visibility', () => {
      // Wait multiple frames to ensure ResizeObserver has fired
      const waitForResize = async () => {
        await ctx.nextFrame();
        await ctx.nextFrame();
      };

      it('hides expander when content is not truncated', async () => {
        const shortTextTemplate = `
          <div data-controller="truncation" data-truncation-expanded-value="false">
            <div data-truncation-target="truncate" style="width: 500px; overflow: hidden;">
              <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
                Short text
              </span>
            </div>
            <div data-truncation-target="expander">
              <button type="button">Toggle</button>
            </div>
          </div>
        `;

        ctx.appendHTML(shortTextTemplate);
        await waitForResize();

        const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

        expect(expander.hidden).toBe(true);
      });

      it('shows expander when content is truncated', async () => {
        const longTextTemplate = `
          <div data-controller="truncation" data-truncation-expanded-value="false">
            <div data-truncation-target="truncate" style="width: 50px; overflow: hidden;">
              <span class="Truncate-text" style="display: inline-block; white-space: nowrap; width: 300px;">
                This is a very long text that should definitely be truncated
              </span>
            </div>
            <div data-truncation-target="expander">
              <button type="button">Toggle</button>
            </div>
          </div>
        `;

        ctx.appendHTML(longTextTemplate);

        const truncateText = ctx.container.querySelector<HTMLElement>('.Truncate-text')!;
        Object.defineProperty(truncateText, 'scrollWidth', { value: 300, configurable: true });
        Object.defineProperty(truncateText, 'clientWidth', { value: 50, configurable: true });

        await waitForResize();

        const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

        expect(expander.hidden).toBe(false);
      });
    });

    describe('resize() method', () => {
      it('calls update() when resize is triggered', async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();

        const controller = ctx.getController<TruncationController>('truncation');

        // Spy on the private update method to verify resize() calls it
        const updateSpy = vi.spyOn(controller as any, 'update');

        controller.resize();

        expect(updateSpy).toHaveBeenCalledWith();
      });

      it('updates expander visibility when content dimensions change', async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();

        const controller = ctx.getController<TruncationController>('truncation');
        const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;
        const truncateText = ctx.container.querySelector<HTMLElement>('.Truncate-text')!;

        const originalScrollWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'scrollWidth');
        const originalClientWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientWidth');

        // Simulate not truncated: scrollWidth === clientWidth
        Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 100 });
        Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 100 });
        controller.resize();

        expect(expander.hidden).toBe(true);

        // Simulate truncated: scrollWidth > clientWidth
        Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 200 });
        Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 100 });
        controller.resize();

        expect(expander.hidden).toBe(false);

        // Simulate not truncated again
        Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 50 });
        Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 50 });
        controller.resize();

        expect(expander.hidden).toBe(true);

        if (originalScrollWidth) {
          Object.defineProperty(HTMLElement.prototype, 'scrollWidth', originalScrollWidth);
        }
        if (originalClientWidth) {
          Object.defineProperty(HTMLElement.prototype, 'clientWidth', originalClientWidth);
        }
      });

      it('keeps expander visible when expanded even if not truncated', async () => {
        ctx.appendHTML(horizontalTemplate);
        await ctx.nextFrame();

        const controller = ctx.getController<TruncationController>('truncation');
        const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

        // Initially short text, expander should be hidden
        controller.resize();

        expect(expander.hidden).toBe(true);

        // Expand the text
        controller.expandedValue = true;
        await ctx.nextFrame();

        // When expanded, expander should remain visible even if not truncated
        expect(expander.hidden).toBe(false);
      });
    });
  });

  describe('vertical mode', () => {
    it('connects successfully', async () => {
      ctx.appendHTML(verticalTemplate);
      await ctx.nextFrame();

      const controller = ctx.getController('truncation');

      expect(controller).toBeDefined();
    });

    it('detects vertical truncation via scrollHeight > clientHeight', async () => {
      ctx.appendHTML(verticalTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 200 });
      Object.defineProperty(truncateEl, 'clientHeight', { configurable: true, value: 60 });

      const controller = ctx.getController<TruncationController>('truncation');
      controller.resize();

      expect(expander.hidden).toBe(false);
    });

    it('hides expander when content fits within line-clamp', async () => {
      ctx.appendHTML(verticalTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 60 });
      Object.defineProperty(truncateEl, 'clientHeight', { configurable: true, value: 60 });

      const controller = ctx.getController<TruncationController>('truncation');
      controller.resize();

      expect(expander.hidden).toBe(true);
    });

    it('toggles expandable-text--expanded class instead of Truncate--expanded', async () => {
      ctx.appendHTML(verticalTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const controller = ctx.getController<TruncationController>('truncation');

      controller.expandedValue = true;
      await ctx.nextFrame();

      expect(truncateEl).toHaveClass('expandable-text--expanded');
      expect(truncateEl).not.toHaveClass('Truncate--expanded');

      controller.expandedValue = false;
      await ctx.nextFrame();

      expect(truncateEl).not.toHaveClass('expandable-text--expanded');
    });

    it('handles click to toggle expansion', async () => {
      ctx.appendHTML(verticalTemplate);
      await ctx.nextFrame();

      const button = ctx.screen.getByRole('button', { name: 'Expand text', hidden: true });
      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

      button.click();
      await ctx.nextFrame();

      expect(truncateEl).toHaveClass('expandable-text--expanded');
      expect(button).toHaveAttribute('aria-expanded', 'true');

      button.click();
      await ctx.nextFrame();

      expect(truncateEl).not.toHaveClass('expandable-text--expanded');
      expect(button).toHaveAttribute('aria-expanded', 'false');
    });
  });

  describe('dialog mode (inline: false)', () => {
    it('does not attach click handler to expander', async () => {
      ctx.appendHTML(dialogTemplate);
      await ctx.nextFrame();

      const button = ctx.container.querySelector<HTMLButtonElement>('[data-truncation-target="expander"] button')!;
      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

      button.click();
      await ctx.nextFrame();

      expect(truncateEl).not.toHaveClass('expandable-text--expanded');
    });

    it('still manages expander visibility based on truncation', async () => {
      ctx.appendHTML(dialogTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 200 });
      Object.defineProperty(truncateEl, 'clientHeight', { configurable: true, value: 60 });

      const controller = ctx.getController<TruncationController>('truncation');
      controller.resize();

      expect(expander.hidden).toBe(false);
    });

    it('preserves server-rendered expander when content fits but has omitted paragraphs', async () => {
      const serverVisibleTemplate = `
        <div data-controller="truncation" data-truncation-expanded-value="false" data-truncation-mode-value="vertical" data-truncation-inline-value="false">
          <div data-truncation-target="truncate" class="line-clamp-3" style="overflow: hidden;">
            <span>Short first paragraph that fits.</span>
          </div>
          <div data-truncation-target="expander">
            <button type="button" data-show-dialog-id="my-dialog">Toggle</button>
          </div>
        </div>
      `;

      ctx.appendHTML(serverVisibleTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      // Content fits — no physical truncation
      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 40 });
      Object.defineProperty(truncateEl, 'clientHeight', { configurable: true, value: 60 });

      const controller = ctx.getController<TruncationController>('truncation');
      controller.resize();

      // Expander must stay visible — server decided to show it because full content has more paragraphs
      expect(expander.hidden).toBe(false);
    });

    it('toggles a server-hidden expander based on truncation', async () => {
      const serverHiddenTemplate = `
        <div data-controller="truncation" data-truncation-expanded-value="false" data-truncation-mode-value="vertical" data-truncation-inline-value="false">
          <div data-truncation-target="truncate" class="line-clamp-3" style="overflow: hidden;">
            <span>Single paragraph.</span>
          </div>
          <div data-truncation-target="expander" hidden>
            <button type="button" data-show-dialog-id="my-dialog">Toggle</button>
          </div>
        </div>
      `;

      ctx.appendHTML(serverHiddenTemplate);
      await ctx.nextFrame();

      const truncateEl = ctx.container.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const expander = ctx.container.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;
      const controller = ctx.getController<TruncationController>('truncation');

      // Content fits — server-hidden expander stays hidden
      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 60 });
      Object.defineProperty(truncateEl, 'clientHeight', { configurable: true, value: 60 });
      controller.resize();

      expect(expander.hidden).toBe(true);

      // Becomes truncated — expander is revealed
      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 200 });
      controller.resize();

      expect(expander.hidden).toBe(false);

      // No longer truncated after a resize — expander is hidden again
      Object.defineProperty(truncateEl, 'scrollHeight', { configurable: true, value: 60 });
      controller.resize();

      expect(expander.hidden).toBe(true);
    });
  });
});
