export function toDashedCase(camelCase:string):string {
  return camelCase.replace(
    /([a-z0-9])([A-Z])/g,
    (_:string, a:string, b:string) => `${a}-${b.toLowerCase()}`,
  );
}

export function toCamelCase(dashedCase:string):string {
  return dashedCase.replace(/[-:]([a-z])/g, (_:string, b:string) => `${b.toUpperCase()}`);
}
