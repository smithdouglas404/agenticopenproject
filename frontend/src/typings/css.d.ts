
declare module "*.css?raw" {
  const src: string;
  export default src;
}

declare module '@blocknote/mantine/style.css?url' {
  const url:string;
  export default url;
}
