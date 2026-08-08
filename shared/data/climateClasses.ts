import type { ClimateClass } from '../types.ts';

export interface ClimateClassMeta {
  id: ClimateClass;
  name: string;
  description: string;
  colors: { bg: string; border: string; text: string };
}

const CLIMATE_CLASSES: ClimateClassMeta[] = [
  {
    id: 'maritime',
    name: 'Maritime',
    description: 'Moderate temperatures and ocean influence with smaller seasonal swings.',
    colors: { bg: '#0b1f2a', border: '#3b82f6', text: '#dbeafe' }
  },
  {
    id: 'continental',
    name: 'Continental',
    description: 'Cold winters, warm summers, and large seasonal and diurnal shifts.',
    colors: { bg: '#1f0f2a', border: '#a855f7', text: '#f3e8ff' }
  },
  {
    id: 'cool',
    name: 'Cool',
    description: 'Lower average temperatures, slower ripening, high-acid wine styles.',
    colors: { bg: '#0b1f3a', border: '#3b82f6', text: '#dbeafe' }
  },
  {
    id: 'warm',
    name: 'Warm',
    description: 'Consistently warmer conditions producing riper, fuller-bodied wines.',
    colors: { bg: '#3b1a0a', border: '#f59e0b', text: '#fffbeb' }
  },
  {
    id: 'mediterranean',
    name: 'Mediterranean',
    description: 'Sunny, dry summers and mild winters with coastal influence and tempered extremes.',
    colors: { bg: '#2a2110', border: '#f97316', text: '#ffedd5' }
  }
];

export const CLIMATE_CLASS_MAP: Record<ClimateClass, ClimateClassMeta> = CLIMATE_CLASSES.reduce((acc, cls) => {
  acc[cls.id] = cls;
  return acc;
}, {} as Record<ClimateClass, ClimateClassMeta>);
