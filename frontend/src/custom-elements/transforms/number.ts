import { Transform } from './types';

const number:Transform<number> = {
  stringify: (value) => `${value}`,
  parse: (value) => parseFloat(value),
};

export default number;
