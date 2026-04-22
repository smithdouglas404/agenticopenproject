import { toCamelCase } from '../utils';

import { Transform } from './types';

const method_:Transform<(...args:unknown[]) => unknown> = {
  stringify: (value) => value.name,
  parse: (value, attribute, element) => {
    const fn = (() => {
      const functionName = toCamelCase(attribute);

      //@ts-expect-error
      if (typeof element !== 'undefined' && functionName in element.container) {
        // @ts-expect-error
        return element.container[functionName];
      }
    })();

    return typeof fn === 'function' ? fn.bind(element) : undefined;
  },
};

export default method_;
