import { TextInputProps } from '@primer/react';


interface InlineDateRangeFieldProps extends Omit<TextInputProps, 'value' | 'onChange'> {
  value:[string, string]; // [startDate, endDate]
  onChange:(value:[string, string]) => void;
}

 declare module 'react/jsx-runtime' {
namespace JSX {
  interface IntrinsicElements {
    'opce-range-date-picker':React.DetailedHTMLProps<
      React.HTMLAttributes<HTMLElement>,
      HTMLElement
    > & {
      start?:string;
      end?:string;
    };
  }
}
 }


export function InlineDateRangeField({ value, onChange, ...rest }:InlineDateRangeFieldProps) {
   const [startValue, endValue] = value;
    const dataValue = value ? value.join(' - ') : null;

   return (
    <opce-range-date-picker data-value={JSON.stringify(dataValue)}></opce-range-date-picker>
   );
}


// export function InlineDateRangeField({ value, onChange, ...rest }:InlineDateRangeFieldProps) {
//   const [startValue, endValue] = value;

//   const handleStartChange = (e:React.ChangeEvent<HTMLInputElement>) => {
//     const newStart = e.target.value;
//     const newEnd = endValue && endValue < newStart ? newStart : endValue;
//     onChange([newStart, newEnd]);
//   };

//   const handleEndChange = (e:React.ChangeEvent<HTMLInputElement>) => {
//     const newEnd = e.target.value;
//     onChange([startValue, newEnd]);
//   };

//   return (
//     <Stack direction="horizontal" gap="condensed">
//       <FormControl>
//         <FormControl.Label visuallyHidden={true}>Start date</FormControl.Label>
//         <TextInput type="date" value={startValue} onChange={handleStartChange} max={endValue || undefined} {...rest} />
//       </FormControl>
//       <FormControl>
//         <FormControl.Label visuallyHidden={true}>End date</FormControl.Label>
//         <TextInput type="date" value={endValue} onChange={handleEndChange} min={startValue || undefined} {...rest} />
//       </FormControl>
//     </Stack>
//   );
// }
