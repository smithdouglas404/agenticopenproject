import boolean from './boolean';
import function_ from './function';
import json from './json';
import method_ from './method';
import number from './number';
import string from './string';

export type { Transform } from './types';

const transforms = {
  string,
  number,
  boolean,
  function: function_,
  method: method_,
  json,
};

export type R2WCType = keyof typeof transforms;

export default transforms;
