import { useThree } from '@react-three/fiber';

/** Rótulos HTML menores em telas estreitas, para não cobrirem a cena no celular. */
export function useLabelScale(): number {
  const width = useThree((s) => s.size.width);
  return Math.min(1, Math.max(0.5, width / 1100));
}
