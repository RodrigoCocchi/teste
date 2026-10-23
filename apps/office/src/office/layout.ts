import { z } from 'zod';
import { roomSchema } from '@nexus/shared';
import rawLayout from './office-layout.json';

const point = z.tuple([z.number(), z.number()]);
export type Point = z.infer<typeof point>;

const layoutSchema = z.object({
  floor: z.object({ width: z.number().positive(), depth: z.number().positive() }),
  rooms: z.array(
    z.object({
      id: roomSchema,
      name: z.string(),
      bounds: z.tuple([z.number(), z.number(), z.number(), z.number()]),
      tint: z.string(),
    }),
  ),
  walls: z.array(
    z.object({
      from: point,
      to: point,
      kind: z.enum(['solid', 'glass']),
      /** Opcional: paredes voltadas para a câmera ficam baixas (corte "casa de bonecas"). */
      height: z.number().positive().optional(),
      doors: z.array(z.object({ at: z.number(), width: z.number().positive() })).default([]),
    }),
  ),
  desks: z.array(z.object({ id: z.string(), position: point, rotation: z.number() })),
  furniture: z.array(
    z.object({
      type: z.enum(['rack', 'meeting_table', 'shelf', 'sofa', 'plant']),
      position: point,
      rotation: z.number(),
    }),
  ),
  meetingSeats: z.array(point).min(7),
  meetingCenter: point,
});

export type OfficeLayout = z.infer<typeof layoutSchema>;
export type Desk = OfficeLayout['desks'][number];
export type Furniture = OfficeLayout['furniture'][number];
export type Wall = OfficeLayout['walls'][number];

export const OFFICE_LAYOUT: OfficeLayout = layoutSchema.parse(rawLayout);

/** Tamanho (largura em x, profundidade em z) antes da rotação. */
export const FOOTPRINT: Record<Furniture['type'] | 'desk', Point> = {
  desk: [1.6, 0.8],
  rack: [0.7, 1.0],
  meeting_table: [3.6, 1.4],
  shelf: [1.8, 0.4],
  sofa: [2.0, 0.8],
  plant: [0.5, 0.5],
};

export const WALL_THICKNESS = 0.12;
const SEAT_OFFSET = 0.85;

export const deg = (d: number) => (d * Math.PI) / 180;

/** Rotaciona um vetor local (x, z) pelo ângulo `rotationDeg` em torno de y (convenção do three.js). */
export function rotate([x, z]: Point, rotationDeg: number): Point {
  const a = deg(rotationDeg);
  return [x * Math.cos(a) + z * Math.sin(a), -x * Math.sin(a) + z * Math.cos(a)];
}

const add = (a: Point, b: Point): Point => [a[0] + b[0], a[1] + b[1]];

export function findDesk(layout: OfficeLayout, id: string): Desk {
  const desk = layout.desks.find((d) => d.id === id);
  if (!desk) throw new Error(`Mesa desconhecida no layout: ${id}`);
  return desk;
}

/** Ponto da cadeira (onde o agente senta) e o ângulo em que ele fica de frente para a mesa. */
export function seatOf(desk: Desk): { point: Point; facing: number } {
  return {
    point: add(desk.position, rotate([0, SEAT_OFFSET], desk.rotation)),
    facing: deg(desk.rotation) + Math.PI,
  };
}

/** Onde um visitante fica de pé ao lado da mesa, olhando para quem está sentado. */
export function visitorSpotOf(desk: Desk): { point: Point; facing: number } {
  const point = add(desk.position, rotate([0.6, 1.4], desk.rotation));
  const seat = seatOf(desk).point;
  return { point, facing: facingTowards(point, seat) };
}

/** Ângulo y para olhar de `from` em direção a `to` (frente do modelo = +z). */
export function facingTowards(from: Point, to: Point): number {
  return Math.atan2(to[0] - from[0], to[1] - from[1]);
}

/** Segmentos sólidos de uma parede, descontando as portas. */
export function wallSegments(wall: Wall): Array<[Point, Point]> {
  const [x1, z1] = wall.from;
  const [x2, z2] = wall.to;
  const length = Math.hypot(x2 - x1, z2 - z1);
  const dir: Point = [(x2 - x1) / length, (z2 - z1) / length];
  const at = (t: number): Point => [x1 + dir[0] * t, z1 + dir[1] * t];
  const gaps = [...wall.doors].sort((a, b) => a.at - b.at);
  const segments: Array<[Point, Point]> = [];
  let cursor = 0;
  for (const door of gaps) {
    const start = door.at - door.width / 2;
    if (start > cursor) segments.push([at(cursor), at(start)]);
    cursor = door.at + door.width / 2;
  }
  if (cursor < length) segments.push([at(cursor), at(length)]);
  return segments;
}
