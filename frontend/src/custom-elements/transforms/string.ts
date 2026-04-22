import { Transform } from './types';

const string:Transform<string> = {
  stringify: (value) => value,
  parse: (value) => value,
};

export default string;
