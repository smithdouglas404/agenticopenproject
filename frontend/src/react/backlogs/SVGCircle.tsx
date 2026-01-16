
interface SvgCircleProps {
  size?:number;
  radius?:number;
  stroke?:string;
  strokeWidth?:number;
  fill?:string;
}

const SvgCircle:React.FC<SvgCircleProps> = ({
  size = 16,
  radius = size / 2,
  fill = 'skyblue',
}) => {
  const center = size / 2;

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle
        cx={center}
        cy={center}
        r={radius}
        fill={fill}
      />
    </svg>
  );
};

export default SvgCircle;
