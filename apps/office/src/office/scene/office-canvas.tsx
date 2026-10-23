'use client';

import {
  AdaptiveDpr,
  Environment,
  Lightformer,
  OrbitControls,
  PerformanceMonitor,
} from '@react-three/drei';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Bloom, EffectComposer, N8AO, SMAA, ToneMapping } from '@react-three/postprocessing';
import { ToneMappingMode } from 'postprocessing';
import { useEffect, useMemo, useRef, useState, type ComponentRef } from 'react';
import { NoToneMapping, Vector3 } from 'three';
import { useOfficeStore } from '@/lib/office-store';
import { AVATAR_POSITIONS, Avatar } from './avatar';
import { Building } from './building';
import { FurnitureSet } from './furniture';

export type Quality = 'high' | 'low';

const BASE_TARGET = new Vector3(0, 0, -1.5);

/** A partir de 1024 px o painel lateral fica sobre a cena (~25% da largura, à direita). */
const PANEL_OVERLAY_MIN_WIDTH = 1024;

/** Centro da visão geral: com o painel sobreposto, desloca a cena para a área livre. */
function overviewTarget(aspect: number, overlay: boolean): Vector3 {
  if (aspect < 1) return new Vector3(0, 0, -2.5);
  return new Vector3(overlay ? 5 : 0, 0, -1);
}

/**
 * Enquadramento inicial: ~22 m de largura em telas largas; em tela vertical (celular)
 * aproxima e baixa a câmera para os agentes não ficarem minúsculos (dá para arrastar).
 */
function overviewPosition(aspect: number, overlay: boolean): Vector3 {
  const vFov = (38 * Math.PI) / 180;
  const hHalf = Math.atan(Math.tan(vFov / 2) * aspect);
  const width = aspect < 1 ? 13 : overlay ? 38 : 28;
  const distance = Math.min(42, Math.max(14, width / 2 / Math.tan(hHalf)));
  // Em tela vertical a câmera fica mais "de cima" para não sobrar fundo vazio.
  const [up, back] = aspect < 1 ? [0.92, 0.5] : [0.72, 0.62];
  return new Vector3(0, distance * up, distance * back).add(overviewTarget(aspect, overlay));
}

export function OfficeCanvas({ resetSignal }: { resetSignal: number }) {
  // `?q=low` força o modo leve (celulares fracos); senão começa no alto e degrada sozinho.
  const [quality, setQuality] = useState<Quality>(() =>
    typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('q') === 'low'
      ? 'low'
      : 'high',
  );
  const roster = useOfficeStore((s) => s.roster);
  const select = useOfficeStore((s) => s.select);

  return (
    <Canvas
      shadows
      dpr={quality === 'high' ? [1, 2] : [1, 1.25]}
      gl={{ antialias: false, powerPreference: 'high-performance', toneMapping: NoToneMapping }}
      camera={{ fov: 38, near: 0.3, far: 200, position: [0, 20, 18] }}
      onPointerMissed={() => select(null)}
      data-testid="office-canvas"
    >
      <color attach="background" args={['#0b0e15']} />
      <fog attach="fog" args={['#0b0e15', 45, 90]} />
      <PerformanceMonitor onDecline={() => setQuality('low')} flipflops={2} />
      <AdaptiveDpr pixelated={false} />

      <Lights quality={quality} />
      <Environment resolution={256} environmentIntensity={0.55}>
        <Lightformer
          form="rect"
          intensity={3}
          color="#fff4e6"
          position={[0, 8, 0]}
          rotation-x={Math.PI / 2}
          scale={[20, 12, 1]}
        />
        <Lightformer
          form="rect"
          intensity={1.5}
          color="#bcd4ff"
          position={[-12, 4, 6]}
          rotation-y={Math.PI / 2}
          scale={[10, 4, 1]}
        />
        <Lightformer
          form="rect"
          intensity={1}
          color="#ffd9b0"
          position={[12, 4, -6]}
          rotation-y={-Math.PI / 2}
          scale={[10, 4, 1]}
        />
      </Environment>

      <Building />
      <FurnitureSet />
      {roster.map((agent) => (
        <Avatar key={agent.key} agent={agent} />
      ))}

      <CameraRig resetSignal={resetSignal} />

      <EffectComposer multisampling={0} enableNormalPass={false}>
        {quality === 'high' ? (
          <N8AO aoRadius={0.8} intensity={2.2} distanceFalloff={0.6} halfRes />
        ) : (
          <></>
        )}
        <Bloom mipmapBlur luminanceThreshold={1} luminanceSmoothing={0.2} intensity={0.75} />
        <ToneMapping mode={ToneMappingMode.ACES_FILMIC} />
        <SMAA />
      </EffectComposer>
    </Canvas>
  );
}

function Lights({ quality }: { quality: Quality }) {
  const size = quality === 'high' ? 2048 : 1024;
  return (
    <>
      <hemisphereLight args={['#dfe7ff', '#2a2420', 0.7]} />
      <directionalLight
        key={size}
        castShadow
        position={[9, 16, 8]}
        intensity={2.4}
        color="#fff1e0"
        shadow-mapSize={[size, size]}
        shadow-bias={-0.0004}
        shadow-normalBias={0.03}
        shadow-radius={4}
        shadow-camera-left={-17}
        shadow-camera-right={17}
        shadow-camera-top={12}
        shadow-camera-bottom={-12}
        shadow-camera-near={1}
        shadow-camera-far={45}
      />
      <pointLight position={[-10.5, 2.3, -6]} intensity={6} distance={7} color="#60a5fa" />
      <pointLight position={[3, 2.3, -6]} intensity={4} distance={7} color="#ffd8a8" />
    </>
  );
}

/** Órbita livre; ao selecionar um agente a câmera o segue mantendo o ângulo escolhido. */
function CameraRig({ resetSignal }: { resetSignal: number }) {
  const controls = useRef<ComponentRef<typeof OrbitControls>>(null);
  const camera = useThree((s) => s.camera);
  const aspect = useThree((s) => s.size.width / Math.max(1, s.size.height));
  const overlay = useThree((s) => s.size.width >= PANEL_OVERLAY_MIN_WIDTH);
  const resetting = useRef(true);
  const overview = useMemo(() => overviewPosition(aspect, overlay), [aspect, overlay]);
  const overviewCenter = useMemo(() => overviewTarget(aspect, overlay), [aspect, overlay]);
  const delta = useMemo(() => new Vector3(), []);

  useEffect(() => {
    resetting.current = true;
  }, [resetSignal, overview]);

  useFrame((_, dt) => {
    const c = controls.current;
    if (!c) return;
    const { selected, following } = useOfficeStore.getState();
    const k = 1 - Math.exp(-dt * 3);

    if (selected && following) {
      resetting.current = false;
      const p = AVATAR_POSITIONS.get(selected);
      if (p) {
        delta.set(p.x, 0.8, p.z).sub(c.target).multiplyScalar(k);
        c.target.add(delta);
        camera.position.add(delta);
      }
    } else if (resetting.current) {
      c.target.lerp(overviewCenter, k);
      camera.position.lerp(overview, k);
      if (camera.position.distanceTo(overview) < 0.05) resetting.current = false;
    }
    c.update();
  });

  return (
    <OrbitControls
      ref={controls}
      makeDefault
      enableDamping
      dampingFactor={0.08}
      minDistance={5}
      maxDistance={48}
      maxPolarAngle={1.25}
      minPolarAngle={0.25}
      target={BASE_TARGET.toArray()}
      onStart={() => {
        resetting.current = false;
      }}
    />
  );
}
