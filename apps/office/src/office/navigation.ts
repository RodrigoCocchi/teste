import {
  FOOTPRINT,
  WALL_THICKNESS,
  rotate,
  wallSegments,
  type OfficeLayout,
  type Point,
} from './layout';

/** Raio do agente: obstáculos são "inflados" por ele para ninguém atravessar quinas. */
export const AGENT_RADIUS = 0.28;

/**
 * Grade de navegação gerada a partir do layout (paredes com portas + móveis).
 * Fase 2 usa grade + A*; dá o mesmo resultado de um navmesh para um piso plano
 * e é trivial de testar. Cadeiras e pontos de visita ficam sempre livres.
 */
export class NavGrid {
  readonly cols: number;
  readonly rows: number;
  private readonly blocked: Uint8Array;
  private readonly minX: number;
  private readonly minZ: number;

  constructor(
    layout: OfficeLayout,
    readonly cell = 0.2,
  ) {
    this.minX = -layout.floor.width / 2;
    this.minZ = -layout.floor.depth / 2;
    this.cols = Math.round(layout.floor.width / cell);
    this.rows = Math.round(layout.floor.depth / cell);
    this.blocked = new Uint8Array(this.cols * this.rows);

    for (const wall of layout.walls) {
      for (const [a, b] of wallSegments(wall))
        this.blockSegment(a, b, WALL_THICKNESS / 2 + AGENT_RADIUS);
    }
    for (const desk of layout.desks) this.blockBox(desk.position, FOOTPRINT.desk, desk.rotation);
    for (const item of layout.furniture)
      this.blockBox(item.position, FOOTPRINT[item.type], item.rotation);
  }

  toCell([x, z]: Point): [number, number] {
    return [
      Math.min(this.cols - 1, Math.max(0, Math.floor((x - this.minX) / this.cell))),
      Math.min(this.rows - 1, Math.max(0, Math.floor((z - this.minZ) / this.cell))),
    ];
  }

  toPoint([c, r]: [number, number]): Point {
    return [this.minX + (c + 0.5) * this.cell, this.minZ + (r + 0.5) * this.cell];
  }

  isWalkable(c: number, r: number): boolean {
    return (
      c >= 0 && r >= 0 && c < this.cols && r < this.rows && this.blocked[r * this.cols + c] === 0
    );
  }

  isPointWalkable(p: Point): boolean {
    return this.isWalkable(...this.toCell(p));
  }

  /**
   * Caminho de `from` até `to` (A* 8-direções, sem cortar quinas), suavizado por linha de visada.
   * Pontos de partida/chegada dentro de obstáculo (ex.: cadeira encostada na mesa) são
   * ligados à célula livre mais próxima. Retorna `null` se não houver caminho.
   */
  findPath(from: Point, to: Point): Point[] | null {
    const start = this.nearestWalkable(this.toCell(from));
    const goal = this.nearestWalkable(this.toCell(to));
    if (!start || !goal) return null;

    const key = (c: number, r: number) => r * this.cols + c;
    const startKey = key(...start);
    const goalKey = key(...goal);
    const g = new Float32Array(this.cols * this.rows).fill(Infinity);
    const came = new Int32Array(this.cols * this.rows).fill(-1);
    const closed = new Uint8Array(this.cols * this.rows);
    const open = new MinHeap();
    const h = (c: number, r: number) => {
      const dx = Math.abs(c - goal[0]);
      const dz = Math.abs(r - goal[1]);
      return Math.max(dx, dz) + (Math.SQRT2 - 1) * Math.min(dx, dz);
    };

    g[startKey] = 0;
    open.push(startKey, h(...start));
    while (open.size > 0) {
      const current = open.pop();
      if (current === goalKey) break;
      if (closed[current]) continue;
      closed[current] = 1;
      const c = current % this.cols;
      const r = (current - c) / this.cols;
      for (let dc = -1; dc <= 1; dc++) {
        for (let dr = -1; dr <= 1; dr++) {
          if (dc === 0 && dr === 0) continue;
          const nc = c + dc;
          const nr = r + dr;
          if (!this.isWalkable(nc, nr)) continue;
          if (dc !== 0 && dr !== 0 && (!this.isWalkable(c + dc, r) || !this.isWalkable(c, r + dr)))
            continue;
          const next = key(nc, nr);
          const cost = g[current]! + (dc !== 0 && dr !== 0 ? Math.SQRT2 : 1);
          if (cost < g[next]!) {
            g[next] = cost;
            came[next] = current;
            open.push(next, cost + h(nc, nr));
          }
        }
      }
    }
    if (startKey !== goalKey && came[goalKey] === -1) return null;

    const cells: Array<[number, number]> = [];
    for (let k = goalKey; k !== -1; k = came[k]!) {
      cells.push([k % this.cols, Math.floor(k / this.cols)]);
      if (k === startKey) break;
    }
    cells.reverse();
    const middle = this.smooth(cells).map((cell) => this.toPoint(cell));
    // Sai do ponto real (ex.: a cadeira) e chega exatamente no destino.
    return [from, ...(this.isPointWalkable(from) ? middle.slice(1) : middle), to];
  }

  private smooth(cells: Array<[number, number]>): Array<[number, number]> {
    if (cells.length <= 2) return cells;
    const out = [cells[0]!];
    let anchor = 0;
    for (let i = 2; i < cells.length; i++) {
      if (!this.lineOfSight(cells[anchor]!, cells[i]!)) {
        out.push(cells[i - 1]!);
        anchor = i - 1;
      }
    }
    out.push(cells[cells.length - 1]!);
    return out;
  }

  /** Linha de visada conservadora: amostra o segmento a cada 1/4 de célula. */
  lineOfSight(a: [number, number], b: [number, number]): boolean {
    const steps = Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) * 4);
    for (let i = 0; i <= steps; i++) {
      const t = steps === 0 ? 0 : i / steps;
      const x = a[0] + (b[0] - a[0]) * t;
      const z = a[1] + (b[1] - a[1]) * t;
      for (const [c, r] of [
        [Math.floor(x + 0.5), Math.floor(z + 0.5)],
        [Math.floor(x + 0.2), Math.floor(z + 0.5)],
        [Math.floor(x + 0.8), Math.floor(z + 0.5)],
        [Math.floor(x + 0.5), Math.floor(z + 0.2)],
        [Math.floor(x + 0.5), Math.floor(z + 0.8)],
      ] as const) {
        if (!this.isWalkable(c, r)) return false;
      }
    }
    return true;
  }

  private nearestWalkable([c, r]: [number, number]): [number, number] | null {
    if (this.isWalkable(c, r)) return [c, r];
    for (let radius = 1; radius < 20; radius++) {
      let best: [number, number] | null = null;
      let bestDist = Infinity;
      for (let dc = -radius; dc <= radius; dc++) {
        for (let dr = -radius; dr <= radius; dr++) {
          if (Math.max(Math.abs(dc), Math.abs(dr)) !== radius || !this.isWalkable(c + dc, r + dr))
            continue;
          const d = dc * dc + dr * dr;
          if (d < bestDist) {
            bestDist = d;
            best = [c + dc, r + dr];
          }
        }
      }
      if (best) return best;
    }
    return null;
  }

  private markCircle(p: Point, radius: number) {
    const [c0, r0] = this.toCell([p[0] - radius, p[1] - radius]);
    const [c1, r1] = this.toCell([p[0] + radius, p[1] + radius]);
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const [x, z] = this.toPoint([c, r]);
        if (Math.hypot(x - p[0], z - p[1]) <= radius) this.blocked[r * this.cols + c] = 1;
      }
    }
  }

  private blockSegment(a: Point, b: Point, radius: number) {
    const steps = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / (this.cell / 2)));
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      this.markCircle([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t], radius);
    }
  }

  private blockBox(center: Point, [w, d]: Point, rotationDeg: number) {
    const hw = w / 2 + AGENT_RADIUS;
    const hd = d / 2 + AGENT_RADIUS;
    const [c0, r0] = this.toCell([center[0] - hw - hd, center[1] - hw - hd]);
    const [c1, r1] = this.toCell([center[0] + hw + hd, center[1] + hw + hd]);
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const [x, z] = this.toPoint([c, r]);
        const [lx, lz] = rotate([x - center[0], z - center[1]], -rotationDeg);
        if (Math.abs(lx) <= hw && Math.abs(lz) <= hd) this.blocked[r * this.cols + c] = 1;
      }
    }
  }
}

/** Heap binária mínima de chaves inteiras por prioridade. */
class MinHeap {
  private keys: number[] = [];
  private prio: number[] = [];

  get size() {
    return this.keys.length;
  }

  push(key: number, priority: number) {
    this.keys.push(key);
    this.prio.push(priority);
    let i = this.keys.length - 1;
    while (i > 0) {
      const parent = (i - 1) >> 1;
      if (this.prio[parent]! <= this.prio[i]!) break;
      this.swap(i, parent);
      i = parent;
    }
  }

  pop(): number {
    const top = this.keys[0]!;
    const lastKey = this.keys.pop()!;
    const lastPrio = this.prio.pop()!;
    if (this.keys.length > 0) {
      this.keys[0] = lastKey;
      this.prio[0] = lastPrio;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = i;
        if (l < this.keys.length && this.prio[l]! < this.prio[m]!) m = l;
        if (r < this.keys.length && this.prio[r]! < this.prio[m]!) m = r;
        if (m === i) break;
        this.swap(i, m);
        i = m;
      }
    }
    return top;
  }

  private swap(a: number, b: number) {
    [this.keys[a], this.keys[b]] = [this.keys[b]!, this.keys[a]!];
    [this.prio[a], this.prio[b]] = [this.prio[b]!, this.prio[a]!];
  }
}
