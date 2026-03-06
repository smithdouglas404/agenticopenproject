export interface DialogBridgeProps<TResult> {
  onSubmit:(result:TResult) => void;
  onCancel:() => void;
}
