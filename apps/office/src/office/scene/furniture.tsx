'use client';

import { useFrame } from '@react-three/fiber';
import { useMemo, useRef } from 'react';
import type { InstancedMesh } from 'three';
import { Color, Matrix4, type MeshStandardMaterial } from 'three';
import { useOfficeStore } from '@/lib/office-store';
import { FOOTPRINT, OFFICE_LAYOUT, deg, rotate, type Desk, type Furniture } from '../layout';
import { PALETTE, SCREEN_GLOW } from './look';

export function FurnitureSet() {
  const roster = useOfficeStore((s) => s.roster);
  const ownerOf = useMemo(() => new Map(roster.map((a) => [a.desk, a.key])), [roster]);
  const racks = OFFICE_LAYOUT.furniture.filter((f) => f.type === 'rack');

  return (
    <group>
      {OFFICE_LAYOUT.desks.map((desk) => (
        <DeskUnit key={desk.id} desk={desk} owner={ownerOf.get(desk.id) ?? null} />
      ))}
      {OFFICE_LAYOUT.furniture
        .filter((f) => f.type !== 'rack')
        .map((item, i) => (
          <Item key={i} item={item} />
        ))}
      <Racks racks={racks} />
      <MeetingChairs />
    </group>
  );
}

function DeskUnit({ desk, owner }: { desk: Desk; owner: string | null }) {
  const [w, d] = FOOTPRINT.desk;
  const screen = useRef<MeshStandardMaterial>(null);
  const target = useMemo(() => new Color(), []);

  useFrame((_, dt) => {
    if (!screen.current) return;
    const activity = owner ? (useOfficeStore.getState().agents[owner]?.activity ?? 'idle') : 'idle';
    const glow = owner ? SCREEN_GLOW[activity] : { color: '#1c2333', intensity: 0.35 };
    target.set(glow.color);
    const k = 1 - Math.exp(-dt * 4);
    screen.current.emissive.lerp(target, k);
    screen.current.emissiveIntensity += (glow.intensity - screen.current.emissiveIntensity) * k;
  });

  return (
    <group position={[desk.position[0], 0, desk.position[1]]} rotation-y={deg(desk.rotation)}>
      {/* tampo e pés */}
      <mesh position={[0, 0.74, 0]} castShadow receiveShadow>
        <boxGeometry args={[w, 0.04, d]} />
        <meshStandardMaterial color={PALETTE.desk} roughness={0.45} />
      </mesh>
      {[-1, 1].map((s) => (
        <mesh key={s} position={[s * (w / 2 - 0.05), 0.36, 0]} castShadow>
          <boxGeometry args={[0.04, 0.72, d - 0.1]} />
          <meshStandardMaterial color={PALETTE.deskLeg} metalness={0.6} roughness={0.4} />
        </mesh>
      ))}
      {/* monitor */}
      <group position={[0, 0.76, -0.22]}>
        <mesh position={[0, 0.06, 0]} castShadow>
          <boxGeometry args={[0.22, 0.02, 0.16]} />
          <meshStandardMaterial color={PALETTE.monitor} metalness={0.5} roughness={0.4} />
        </mesh>
        <mesh position={[0, 0.2, 0]} castShadow>
          <boxGeometry args={[0.04, 0.28, 0.03]} />
          <meshStandardMaterial color={PALETTE.monitor} metalness={0.5} roughness={0.4} />
        </mesh>
        <mesh position={[0, 0.42, 0.02]} castShadow>
          <boxGeometry args={[0.72, 0.42, 0.03]} />
          <meshStandardMaterial color={PALETTE.monitor} metalness={0.4} roughness={0.35} />
        </mesh>
        <mesh position={[0, 0.42, 0.037]}>
          <planeGeometry args={[0.68, 0.38]} />
          <meshStandardMaterial
            ref={screen}
            color="#05070b"
            emissive="#1c2333"
            emissiveIntensity={0.35}
            roughness={0.2}
          />
        </mesh>
      </group>
      {/* teclado */}
      <mesh position={[0, 0.77, 0.12]} castShadow>
        <boxGeometry args={[0.44, 0.015, 0.14]} />
        <meshStandardMaterial color="#2a2f38" roughness={0.6} />
      </mesh>
      {/* cadeira (coordenadas locais da mesa) */}
      <group position={[0, 0, 0.85]} rotation-y={Math.PI}>
        <Chair />
      </group>
    </group>
  );
}

function Chair() {
  return (
    <group>
      <mesh position={[0, 0.46, 0]} castShadow>
        <boxGeometry args={[0.46, 0.07, 0.44]} />
        <meshStandardMaterial color={PALETTE.chair} roughness={0.7} />
      </mesh>
      <mesh position={[0, 0.78, -0.21]} castShadow>
        <boxGeometry args={[0.44, 0.56, 0.06]} />
        <meshStandardMaterial color={PALETTE.chair} roughness={0.7} />
      </mesh>
      <mesh position={[0, 0.22, 0]} castShadow>
        <cylinderGeometry args={[0.03, 0.03, 0.42, 10]} />
        <meshStandardMaterial color="#8b93a1" metalness={0.8} roughness={0.3} />
      </mesh>
      <mesh position={[0, 0.03, 0]} receiveShadow>
        <cylinderGeometry args={[0.26, 0.26, 0.04, 20]} />
        <meshStandardMaterial color="#2c3138" metalness={0.5} roughness={0.5} />
      </mesh>
    </group>
  );
}

function MeetingChairs() {
  const { meetingSeats, meetingCenter } = OFFICE_LAYOUT;
  return (
    <group>
      {meetingSeats.map(([x, z], i) => (
        // Encosto do lado oposto à mesa: o agente sentado fica de frente para ela.
        <group
          key={i}
          position={[x, 0, z]}
          rotation-y={Math.atan2(meetingCenter[0] - x, meetingCenter[1] - z)}
        >
          <Chair />
        </group>
      ))}
    </group>
  );
}

function Item({ item }: { item: Furniture }) {
  const [w, d] = FOOTPRINT[item.type];
  const position: [number, number, number] = [item.position[0], 0, item.position[1]];
  const rotationY = deg(item.rotation);

  switch (item.type) {
    case 'meeting_table':
      return (
        <group position={position} rotation-y={rotationY}>
          <mesh position={[0, 0.74, 0]} castShadow receiveShadow>
            <boxGeometry args={[w, 0.06, d]} />
            <meshStandardMaterial color={PALETTE.wood} roughness={0.35} />
          </mesh>
          <mesh position={[0, 0.37, 0]} castShadow>
            <boxGeometry args={[w * 0.6, 0.72, 0.2]} />
            <meshStandardMaterial color={PALETTE.deskLeg} metalness={0.5} roughness={0.4} />
          </mesh>
        </group>
      );
    case 'shelf':
      return (
        <group position={position} rotation-y={rotationY}>
          <mesh position={[0, 1, 0]} castShadow receiveShadow>
            <boxGeometry args={[w, 2, d]} />
            <meshStandardMaterial color={PALETTE.wood} roughness={0.6} />
          </mesh>
          {[0.35, 0.8, 1.25, 1.7].map((y, row) => (
            <group key={y} position={[0, y, d / 2 - 0.02]}>
              {Array.from({ length: 9 }, (_, i) => (
                <mesh key={i} position={[-w / 2 + 0.15 + i * 0.19, 0.14, 0]} castShadow>
                  <boxGeometry args={[0.13, 0.26 + ((i + row) % 3) * 0.03, 0.05]} />
                  <meshStandardMaterial
                    color={
                      ['#b45353', '#3d6a9e', '#d9b45a', '#4e8a6a', '#7d5aa6'][(i * 3 + row) % 5]
                    }
                    roughness={0.8}
                  />
                </mesh>
              ))}
            </group>
          ))}
        </group>
      );
    case 'sofa':
      return (
        <group position={position} rotation-y={rotationY}>
          <mesh position={[0, 0.22, 0]} castShadow receiveShadow>
            <boxGeometry args={[w, 0.3, d]} />
            <meshStandardMaterial color={PALETTE.sofa} roughness={0.95} />
          </mesh>
          <mesh position={[0, 0.55, -d / 2 + 0.1]} castShadow>
            <boxGeometry args={[w, 0.5, 0.2]} />
            <meshStandardMaterial color={PALETTE.sofa} roughness={0.95} />
          </mesh>
          {[-1, 1].map((s) => (
            <mesh key={s} position={[s * (w / 2 - 0.1), 0.4, 0]} castShadow>
              <boxGeometry args={[0.2, 0.36, d]} />
              <meshStandardMaterial color={PALETTE.sofa} roughness={0.95} />
            </mesh>
          ))}
        </group>
      );
    case 'plant':
      return (
        <group position={position}>
          <mesh position={[0, 0.22, 0]} castShadow>
            <cylinderGeometry args={[0.2, 0.15, 0.44, 20]} />
            <meshStandardMaterial color={PALETTE.plantPot} roughness={0.5} />
          </mesh>
          {[
            [0, 0.85, 0, 0.32],
            [0.12, 0.65, 0.08, 0.24],
            [-0.12, 0.7, -0.05, 0.26],
            [0.02, 1.08, -0.06, 0.2],
          ].map(([x, y, z, r], i) => (
            <mesh key={i} position={[x!, y!, z!]} castShadow>
              <icosahedronGeometry args={[r, 1]} />
              <meshStandardMaterial color={PALETTE.leaf} roughness={0.8} flatShading />
            </mesh>
          ))}
        </group>
      );
    default:
      return null;
  }
}

const LEDS_PER_RACK = 14;

/** Racks com LEDs piscando (instanced: um único draw call para todos os LEDs). */
function Racks({ racks }: { racks: Furniture[] }) {
  const leds = useRef<InstancedMesh>(null);
  const colors = useMemo(
    () => [new Color('#22c55e'), new Color('#38bdf8'), new Color('#f59e0b')],
    [],
  );
  const matrix = useMemo(() => new Matrix4(), []);
  const scratch = useMemo(() => new Color(), []);
  const [w, d] = FOOTPRINT.rack;
  const count = racks.length * LEDS_PER_RACK;

  const placements = useMemo(
    () =>
      racks.flatMap((rack) =>
        Array.from({ length: LEDS_PER_RACK }, (_, i) => {
          const local = rotate([-w / 2 + 0.12 + (i % 2) * 0.1, d / 2 + 0.01], rack.rotation);
          return [
            rack.position[0] + local[0],
            0.25 + Math.floor(i / 2) * 0.24,
            rack.position[1] + local[1],
          ] as const;
        }),
      ),
    [racks, w, d],
  );

  useFrame(({ clock }) => {
    const mesh = leds.current;
    if (!mesh) return;
    const t = clock.elapsedTime;
    placements.forEach(([x, y, z], i) => {
      matrix.makeTranslation(x, y, z);
      mesh.setMatrixAt(i, matrix);
      const on = Math.sin(t * (2 + (i % 5)) + i * 1.7) > -0.2;
      scratch.copy(colors[i % 3]!).multiplyScalar(on ? 4 : 0.15);
      mesh.setColorAt(i, scratch);
    });
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
  });

  return (
    <group>
      {racks.map((rack, i) => (
        <group
          key={i}
          position={[rack.position[0], 0, rack.position[1]]}
          rotation-y={deg(rack.rotation)}
        >
          <mesh position={[0, 1, 0]} castShadow receiveShadow>
            <boxGeometry args={[w, 2, d]} />
            <meshStandardMaterial color={PALETTE.rack} metalness={0.6} roughness={0.35} />
          </mesh>
          <mesh position={[0, 1, d / 2 + 0.002]}>
            <planeGeometry args={[w - 0.08, 1.9]} />
            <meshStandardMaterial color="#0b0d11" metalness={0.8} roughness={0.25} />
          </mesh>
        </group>
      ))}
      <instancedMesh ref={leds} args={[undefined, undefined, count]}>
        <boxGeometry args={[0.04, 0.02, 0.01]} />
        <meshBasicMaterial toneMapped={false} />
      </instancedMesh>
    </group>
  );
}
