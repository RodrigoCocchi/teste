'use client';

import { Html } from '@react-three/drei';
import { useMemo } from 'react';
import { OFFICE_LAYOUT, WALL_THICKNESS, wallSegments, type Point } from '../layout';
import { useLabelScale } from './label-scale';
import { PALETTE } from './look';

const WALL_HEIGHT = { solid: 2.7, glass: 2.5 } as const;

export function Building() {
  const { floor, rooms, walls } = OFFICE_LAYOUT;
  const labelScale = useLabelScale();
  const segments = useMemo(
    () =>
      walls.flatMap((w) =>
        wallSegments(w).map(([a, b]) => ({ a, b, kind: w.kind, height: w.height })),
      ),
    [walls],
  );

  return (
    <group>
      {/* Piso */}
      <mesh rotation-x={-Math.PI / 2} receiveShadow>
        <planeGeometry args={[floor.width, floor.depth]} />
        <meshStandardMaterial color={PALETTE.floor} roughness={0.82} metalness={0.05} />
      </mesh>

      {/* Tapetes das salas */}
      {rooms.map((room) => {
        const [x1, z1, x2, z2] = room.bounds;
        return (
          <group key={room.id}>
            <mesh
              rotation-x={-Math.PI / 2}
              position={[(x1 + x2) / 2, 0.004, (z1 + z2) / 2]}
              receiveShadow
            >
              <planeGeometry args={[x2 - x1 - 0.2, z2 - z1 - 0.2]} />
              <meshStandardMaterial color={room.tint} roughness={0.95} />
            </mesh>
            <Html
              position={[x1 + 0.35, 0.02, z2 - 0.35]}
              distanceFactor={18 * labelScale}
              zIndexRange={[5, 0]}
              style={{ pointerEvents: 'none' }}
            >
              <span
                className="block whitespace-nowrap text-[13px] font-medium uppercase tracking-[0.18em] text-white/50"
                style={{ transform: 'translate(50%, -50%)' }}
              >
                {room.name}
              </span>
            </Html>
          </group>
        );
      })}

      {segments.map(({ a, b, kind, height }, i) => (
        <WallSegment key={i} a={a} b={b} kind={kind} height={height ?? WALL_HEIGHT[kind]} />
      ))}
    </group>
  );
}

function WallSegment({
  a,
  b,
  kind,
  height,
}: {
  a: Point;
  b: Point;
  kind: 'solid' | 'glass';
  height: number;
}) {
  const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const angle = Math.atan2(-(b[1] - a[1]), b[0] - a[0]);
  const center: [number, number, number] = [(a[0] + b[0]) / 2, height / 2, (a[1] + b[1]) / 2];

  if (kind === 'solid') {
    return (
      <group position={center} rotation-y={angle}>
        <mesh castShadow receiveShadow>
          <boxGeometry args={[length, height, WALL_THICKNESS]} />
          <meshStandardMaterial color={PALETTE.wall} roughness={0.9} />
        </mesh>
        {/* rodapé */}
        <mesh position={[0, -height / 2 + 0.05, 0]}>
          <boxGeometry args={[length, 0.1, WALL_THICKNESS + 0.02]} />
          <meshStandardMaterial color={PALETTE.wallTrim} roughness={0.6} />
        </mesh>
      </group>
    );
  }

  return (
    <group position={center} rotation-y={angle}>
      <mesh>
        <boxGeometry args={[length, height, 0.03]} />
        <meshPhysicalMaterial
          color={PALETTE.glass}
          transparent
          opacity={0.16}
          roughness={0.04}
          metalness={0}
          clearcoat={1}
          envMapIntensity={1.4}
          depthWrite={false}
        />
      </mesh>
      {/* caixilhos de alumínio */}
      {[height / 2 - 0.03, -height / 2 + 0.03].map((y) => (
        <mesh key={y} position={[0, y, 0]} castShadow>
          <boxGeometry args={[length, 0.06, 0.07]} />
          <meshStandardMaterial color={PALETTE.frame} metalness={0.8} roughness={0.3} />
        </mesh>
      ))}
      {Array.from(
        { length: Math.max(0, Math.floor(length / 1.6)) },
        (_, i) => -length / 2 + 1.6 * (i + 1),
      ).map((x) => (
        <mesh key={x} position={[x, 0, 0]} castShadow>
          <boxGeometry args={[0.05, height, 0.07]} />
          <meshStandardMaterial color={PALETTE.frame} metalness={0.8} roughness={0.3} />
        </mesh>
      ))}
    </group>
  );
}
