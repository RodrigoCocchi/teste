import { agentKeySchema } from '@nexus/shared';
import type { AgentLocation } from '@/lib/office-state';
import {
  facingTowards,
  findDesk,
  seatOf,
  visitorSpotOf,
  type OfficeLayout,
  type Point,
} from './layout';

export type Posture = 'seated' | 'standing';

export interface Goal {
  /** Identificador estável: muda apenas quando o destino muda (dispara novo caminho). */
  key: string;
  point: Point;
  facing: number;
  posture: Posture;
}

/**
 * Para onde o agente deve ir: cadeira da reunião durante o standup, ao lado da mesa visitada,
 * ou a própria cadeira.
 */
export function resolveGoal(
  layout: OfficeLayout,
  agentKey: string,
  ownDesk: string,
  location: AgentLocation,
  standup: boolean,
): Goal {
  if (standup) {
    const index = Math.max(0, agentKeySchema.options.indexOf(agentKey as never));
    const point = layout.meetingSeats[index % layout.meetingSeats.length]!;
    return {
      key: `meeting:${index}`,
      point,
      facing: facingTowards(point, layout.meetingCenter),
      posture: 'seated',
    };
  }
  if (
    location.kind === 'visit' &&
    location.desk !== ownDesk &&
    layout.desks.some((d) => d.id === location.desk)
  ) {
    const spot = visitorSpotOf(findDesk(layout, location.desk));
    return { key: `visit:${location.desk}`, ...spot, posture: 'standing' };
  }
  const seat = seatOf(findDesk(layout, ownDesk));
  return { key: `desk:${ownDesk}`, ...seat, posture: 'seated' };
}
