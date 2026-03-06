import React from 'react';
import { ReactBridge } from './react-bridge';
import type { DialogBridgeProps } from './types';

interface SimpleResult { value:string }

function ImmediateSubmitDialog({ onSubmit }:DialogBridgeProps<SimpleResult>) {
  setTimeout(() => onSubmit({ value: 'submitted' }), 0);
  return React.createElement('div', null, 'dialog');
}

function ImmediateCancelDialog({ onCancel }:DialogBridgeProps<SimpleResult>) {
  setTimeout(() => onCancel(), 0);
  return React.createElement('div', null, 'dialog');
}

describe('ReactBridge', () => {
  describe('openDialog', () => {
    it('resolves with result when onSubmit is called', async () => {
      const result = await ReactBridge.openDialog<SimpleResult>(ImmediateSubmitDialog, {});

      expect(result).toEqual({ value: 'submitted' });
    });

    it('resolves null when onCancel is called', async () => {
      const result = await ReactBridge.openDialog<SimpleResult>(ImmediateCancelDialog, {});

      expect(result).toBeNull();
    });

    it('removes the container div after submit', async () => {
      const before = document.querySelectorAll('[data-react-bridge]').length;
      await ReactBridge.openDialog<SimpleResult>(ImmediateSubmitDialog, {});
      const after = document.querySelectorAll('[data-react-bridge]').length;

      expect(after).toBe(before);
    });

    it('removes the container div after cancel', async () => {
      const before = document.querySelectorAll('[data-react-bridge]').length;
      await ReactBridge.openDialog<SimpleResult>(ImmediateCancelDialog, {});
      const after = document.querySelectorAll('[data-react-bridge]').length;

      expect(after).toBe(before);
    });

    it('handles multiple concurrent dialogs independently', async () => {
      const [result1, result2] = await Promise.all([
        ReactBridge.openDialog<SimpleResult>(ImmediateSubmitDialog, {}),
        ReactBridge.openDialog<SimpleResult>(ImmediateCancelDialog, {}),
      ]);

      expect(result1).toEqual({ value: 'submitted' });
      expect(result2).toBeNull();
    });
  });
});
