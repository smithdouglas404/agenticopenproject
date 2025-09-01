

export function withContentProp<P extends { children?: React.ReactNode }>(
  Component: React.ComponentType<P>
) {
  type Props = Omit<P, "children"> & { content?: React.ReactNode };
  return function Wrapped(props: Props) {
    const { content, ...rest } = props;
    return <Component {...(rest as P)}>{content}</Component>;
  };
}



export function withSlot<P extends { children?: React.ReactNode }>(
  Component: React.ComponentType<P>
) {
  type Props = Omit<P, "children">;
  return function Wrapped(props: Props) {
    return <Component {...(props as P)}><slot /></Component>;
  };
}
