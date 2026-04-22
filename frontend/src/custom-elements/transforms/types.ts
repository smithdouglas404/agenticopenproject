export interface Transform<Type> {
  stringify?:(value:Type, attribute:string, element:HTMLElement) => string
  parse:(value:string, attribute:string, element:HTMLElement) => Type
}
