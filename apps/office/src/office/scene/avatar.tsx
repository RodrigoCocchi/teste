'use client';

import { Html } from '@react-three/drei';
import { useFrame, type ThreeEvent } from '@react-three/fiber';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { Group } from 'three';
import { Vector3 } from 'three';
import { useOfficeStore, type AgentInfo } from '@/lib/office-store';
import type { AgentActivity } from '@/lib/office-state';
import { resolveGoal } from '../goals';
import { OFFICE_LAYOUT } from '../layout';
import { createMotion, stepMotion } from '../motion';
import { NavGrid } from '../navigation';
import { useLabelScale } from './label-scale';
import { AGENT_LOOK, DEFAULT_LOOK } from './look';

export const NAV_GRID = new NavGrid(OFFICE_LAYOUT);

/** Posição atual de cada avatar, lida pela câmera ("seguir agente"). */
export const AVATAR_POSITIONS = new Map<string, Vector3>();

const HIP_STAND = 0.86;
const BUBBLE_MS = 6000;
const HIP_SEAT = 0.52;

const ACTIVITY_LABEL: Record<AgentActivity, string> = {
  idle: 'Disponível',
  thinking: 'Pensando',
  working: 'Trabalhando',
  walking: 'Caminhando',
  talking: 'Conversando',
  waiting_approval: 'Aguardando aprovação',
  done: 'Concluiu',
  error: 'Erro',
};

const DOT: Record<AgentActivity, string> = {
  idle: '#94a3b8',
  thinking: '#a78bfa',
  working: '#38bdf8',
  walking: '#2dd4bf',
  talking: '#a5b4fc',
  waiting_approval: '#fbbf24',
  done: '#34d399',
  error: '#f43f5e',
};

export function Avatar({ agent }: { agent: AgentInfo }) {
  const look = AGENT_LOOK[agent.key] ?? DEFAULT_LOOK;
  const activity = useOfficeStore((s) => s.agents[agent.key]?.activity ?? 'idle');
  const detail = useOfficeStore((s) => s.agents[agent.key]?.detail ?? null);
  const updatedAt = useOfficeStore((s) => s.agents[agent.key]?.updatedAt ?? '');
  // Fala some depois de alguns segundos; estados como "aguardando aprovação" ficam até mudar.
  const [speechVisible, setSpeechVisible] = useState(true);
  useEffect(() => {
    setSpeechVisible(true);
    const timer = setTimeout(() => setSpeechVisible(false), BUBBLE_MS);
    return () => clearTimeout(timer);
  }, [updatedAt, activity]);
  const selected = useOfficeStore((s) => s.selected === agent.key);
  const select = useOfficeStore((s) => s.select);
  const labelScale = useLabelScale();

  const root = useRef<Group>(null);
  const hips = useRef<Group>(null);
  const torso = useRef<Group>(null);
  const head = useRef<Group>(null);
  const armL = useRef<Group>(null);
  const armR = useRef<Group>(null);
  const legL = useRef<Group>(null);
  const legR = useRef<Group>(null);
  const kneeL = useRef<Group>(null);
  const kneeR = useRef<Group>(null);

  const motion = useMemo(() => {
    const m = createMotion(
      resolveGoal(OFFICE_LAYOUT, agent.key, agent.desk, { kind: 'desk' }, false),
    );
    const position = new Vector3(m.x, 0, m.z);
    AVATAR_POSITIONS.set(agent.key, position);
    return { m, position, seed: Math.random() * 100 };
  }, [agent.key, agent.desk]);

  useFrame(({ clock }, rawDt) => {
    // Até 10 fps a velocidade continua correta; abaixo disso a cena desacelera em vez de "teleportar".
    const dt = Math.min(rawDt, 0.1);
    const t = clock.elapsedTime + motion.seed;
    const state = useOfficeStore.getState();
    const self = state.agents[agent.key];
    const goal = resolveGoal(
      OFFICE_LAYOUT,
      agent.key,
      agent.desk,
      self?.location ?? { kind: 'desk' },
      state.standup,
    );
    const m = motion.m;
    const walking = stepMotion(m, goal, dt, NAV_GRID);
    motion.position.set(m.x, 0, m.z);
    const sit = m.sit;
    const swing = walking ? Math.sin(m.walkPhase) : 0;

    if (root.current) {
      root.current.position.copy(motion.position);
      root.current.rotation.y = m.heading;
    }
    if (hips.current) {
      const bob = walking ? Math.abs(Math.cos(m.walkPhase)) * 0.04 : Math.sin(t * 1.6) * 0.006;
      hips.current.position.y = HIP_STAND + (HIP_SEAT - HIP_STAND) * sit + bob;
      // Sentado, o quadril recua para cima da cadeira.
      hips.current.position.z = -0.05 * sit;
    }
    for (const [leg, knee, sign] of [
      [legL, kneeL, 1],
      [legR, kneeR, -1],
    ] as const) {
      if (leg.current) leg.current.rotation.x = (-Math.PI / 2) * sit + swing * 0.55 * sign;
      if (knee.current)
        knee.current.rotation.x = (Math.PI / 2) * sit + Math.max(0, -swing * sign) * 0.7;
    }

    // Braços e cabeça conforme a atividade.
    let armLX = swing * -0.5;
    let armRX = swing * 0.5;
    let armLZ = 0.08;
    let armRZ = -0.08;
    let headX = 0;
    let headY = 0;
    if (!walking) {
      switch (activity) {
        case 'working':
          armLX = -1.15 + Math.sin(t * 14) * 0.06;
          armRX = -1.15 + Math.sin(t * 14 + 1.4) * 0.06;
          armLZ = -0.18;
          armRZ = 0.18;
          headX = 0.12;
          break;
        case 'thinking':
          armRX = -2.3;
          armRZ = 0.5;
          headX = -0.12;
          headY = Math.sin(t * 0.8) * 0.25;
          break;
        case 'talking':
          armRX = -0.7 + Math.sin(t * 4) * 0.35;
          armLX = -0.3 + Math.sin(t * 3 + 1) * 0.2;
          headX = Math.sin(t * 6) * 0.05;
          headY = Math.sin(t * 1.7) * 0.15;
          break;
        case 'done':
          armLX = -2.6 + Math.sin(t * 8) * 0.2;
          armRX = -2.6 + Math.sin(t * 8 + 1) * 0.2;
          armLZ = 0.35;
          armRZ = -0.35;
          break;
        case 'waiting_approval':
          headY = Math.sin(t * 1.2) * 0.4;
          break;
        case 'error':
          headX = 0.3;
          break;
        default:
          headY = Math.sin(t * 0.5) * 0.2;
      }
      if (sit > 0.5 && activity !== 'done' && activity !== 'thinking') {
        armLX = Math.min(armLX, -0.9);
        armRX = Math.min(armRX, -0.9);
      }
    }
    const k = 1 - Math.exp(-dt * 10);
    if (armL.current) {
      armL.current.rotation.x += (armLX - armL.current.rotation.x) * k;
      armL.current.rotation.z += (armLZ - armL.current.rotation.z) * k;
    }
    if (armR.current) {
      armR.current.rotation.x += (armRX - armR.current.rotation.x) * k;
      armR.current.rotation.z += (armRZ - armR.current.rotation.z) * k;
    }
    if (head.current) {
      head.current.rotation.x += (headX - head.current.rotation.x) * k;
      head.current.rotation.y += (headY - head.current.rotation.y) * k;
    }
    if (torso.current) torso.current.rotation.x = activity === 'working' && !walking ? 0.12 : 0;
  });

  const onClick = (e: ThreeEvent<MouseEvent>) => {
    e.stopPropagation();
    select(agent.key);
  };

  const bubble =
    activity === 'talking' && detail && speechVisible
      ? { text: detail, tone: 'talk' as const }
      : activity === 'thinking' && speechVisible
        ? { text: '…', tone: 'think' as const }
        : activity === 'waiting_approval'
          ? { text: 'Aguardando aprovação', tone: 'approval' as const }
          : activity === 'error'
            ? { text: 'Erro', tone: 'error' as const }
            : null;

  return (
    <group ref={root} onClick={onClick} scale={1.12}>
      {selected && (
        <mesh rotation-x={-Math.PI / 2} position={[0, 0.012, 0]}>
          <ringGeometry args={[0.38, 0.46, 48]} />
          <meshBasicMaterial color={look.color} toneMapped={false} transparent opacity={0.9} />
        </mesh>
      )}
      <group ref={hips} position={[0, HIP_STAND, 0]}>
        {/* pernas: coxa → joelho → canela */}
        {[
          [legL, kneeL, 0.1],
          [legR, kneeR, -0.1],
        ].map(([leg, knee, x]) => (
          <group
            key={String(x)}
            ref={leg as React.RefObject<Group>}
            position={[x as number, -0.02, 0]}
          >
            <mesh position={[0, -0.21, 0]} castShadow>
              <capsuleGeometry args={[0.075, 0.28, 6, 12]} />
              <meshStandardMaterial color="#2b3140" roughness={0.8} />
            </mesh>
            <group ref={knee as React.RefObject<Group>} position={[0, -0.42, 0]}>
              <mesh position={[0, -0.19, 0]} castShadow>
                <capsuleGeometry args={[0.065, 0.26, 6, 12]} />
                <meshStandardMaterial color="#2b3140" roughness={0.8} />
              </mesh>
              <mesh position={[0, -0.39, 0.05]} castShadow>
                <boxGeometry args={[0.11, 0.07, 0.24]} />
                <meshStandardMaterial color="#14161b" roughness={0.5} />
              </mesh>
            </group>
          </group>
        ))}

        <group ref={torso}>
          <mesh position={[0, 0.3, 0]} castShadow>
            <capsuleGeometry args={[0.2, 0.32, 8, 20]} />
            <meshStandardMaterial color={look.color} roughness={0.55} />
          </mesh>
          {/* crachá */}
          <mesh position={[0.09, 0.36, 0.19]} rotation-x={-0.1}>
            <boxGeometry args={[0.07, 0.09, 0.01]} />
            <meshStandardMaterial color="#f8fafc" emissive="#ffffff" emissiveIntensity={0.2} />
          </mesh>

          {[
            [armL, 0.27],
            [armR, -0.27],
          ].map(([arm, x]) => (
            <group
              key={String(x)}
              ref={arm as React.RefObject<Group>}
              position={[x as number, 0.5, 0]}
            >
              <mesh position={[0, -0.22, 0]} castShadow>
                <capsuleGeometry args={[0.058, 0.32, 6, 12]} />
                <meshStandardMaterial color={look.color} roughness={0.55} />
              </mesh>
              <mesh position={[0, -0.45, 0]} castShadow>
                <sphereGeometry args={[0.055, 16, 12]} />
                <meshStandardMaterial color={look.skin} roughness={0.6} />
              </mesh>
            </group>
          ))}

          <group ref={head} position={[0, 0.74, 0]}>
            <mesh position={[0, -0.08, 0]}>
              <cylinderGeometry args={[0.055, 0.06, 0.08, 12]} />
              <meshStandardMaterial color={look.skin} roughness={0.6} />
            </mesh>
            <mesh position={[0, 0.06, 0]} castShadow>
              <sphereGeometry args={[0.165, 32, 24]} />
              <meshStandardMaterial color={look.skin} roughness={0.55} />
            </mesh>
            <mesh position={[0, 0.11, -0.02]} scale={[1.04, 0.82, 1.06]} castShadow>
              <sphereGeometry args={[0.168, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2]} />
              <meshStandardMaterial color={look.hair} roughness={0.75} />
            </mesh>
            {[-0.06, 0.06].map((x) => (
              <mesh key={x} position={[x, 0.07, 0.15]}>
                <sphereGeometry args={[0.022, 12, 8]} />
                <meshStandardMaterial color="#0b0d12" roughness={0.2} />
              </mesh>
            ))}
          </group>
        </group>
      </group>
      <Html
        position={[0, 2.02, 0]}
        center
        distanceFactor={16 * labelScale}
        zIndexRange={[20, 10]}
        style={{ pointerEvents: 'none' }}
      >
        <div className="flex select-none flex-col items-center gap-1">
          {bubble && (
            <div
              className={`w-max max-w-[14rem] rounded-2xl px-3 py-1.5 text-center text-[13px] leading-snug shadow-lg backdrop-blur-md ${
                bubble.tone === 'approval'
                  ? 'animate-pulse bg-amber-400/90 font-semibold text-amber-950'
                  : bubble.tone === 'error'
                    ? 'bg-rose-500/90 font-semibold text-white'
                    : 'bg-white/90 text-slate-900'
              }`}
            >
              {bubble.text.length > 70 ? `${bubble.text.slice(0, 67)}…` : bubble.text}
            </div>
          )}
          <div
            className={`flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-0.5 text-[13px] font-medium text-white backdrop-blur-md ${
              selected ? 'bg-black/70 ring-1 ring-white/40' : 'bg-black/45'
            }`}
            title={ACTIVITY_LABEL[activity]}
          >
            <span className="size-1.5 rounded-full" style={{ background: DOT[activity] }} />
            {agent.name}
          </div>
        </div>
      </Html>
    </group>
  );
}
