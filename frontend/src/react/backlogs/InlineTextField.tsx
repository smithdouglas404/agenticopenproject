import { FormControl, TextInput, TextInputProps } from '@primer/react';

interface InlineTextFieldProps extends TextInputProps {
  value:string;
  onChange:TextInputProps['onChange']
}

export default function InlineTextField({ value, onChange, ...rest }:InlineTextFieldProps) {
  return (
    <FormControl>
      <FormControl.Label visuallyHidden={true}>Subject</FormControl.Label>
      <TextInput value={value} onChange={onChange} {...rest} block />
    </FormControl>
  );
}
