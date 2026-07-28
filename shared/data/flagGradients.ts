export interface FlagGradient {
  key: string;
  label: string;
  gradient: string;
}

export const FLAG_GRADIENTS: FlagGradient[] = [
  { key: 'france', label: 'France', gradient: 'linear-gradient(90deg,#1f3f99 33%,#ffffff 33%,#ffffff 66%,#c53030 66%)' },
  { key: 'italy', label: 'Italy', gradient: 'linear-gradient(90deg,#1b9b4c 33%,#ffffff 33%,#ffffff 66%,#c53030 66%)' },
  { key: 'spain', label: 'Spain', gradient: 'linear-gradient(90deg,#c53030 0 20%,#f6ad55 20% 80%,#c53030 80% 100%)' },
  { key: 'portugal', label: 'Portugal', gradient: 'linear-gradient(90deg,#046c4e 45%,#7f1d1d 45%)' },
  { key: 'germany', label: 'Germany', gradient: 'linear-gradient(90deg,#0f172a 33%,#b91c1c 33% 66%,#f59e0b 66%)' },
  { key: 'austria', label: 'Austria', gradient: 'linear-gradient(90deg,#c53030 33%,#ffffff 33% 66%,#c53030 66%)' },
  { key: 'greece', label: 'Greece', gradient: 'linear-gradient(90deg,#2563eb 33%,#e2e8f0 33% 66%,#2563eb 66%)' },
  { key: 'hungary', label: 'Hungary', gradient: 'linear-gradient(90deg,#b91c1c 33%,#ffffff 33% 66%,#16a34a 66%)' },
  { key: 'romania', label: 'Romania', gradient: 'linear-gradient(90deg,#1d4ed8 33%,#facc15 33% 66%,#dc2626 66%)' },
  { key: 'switzerland', label: 'Switzerland', gradient: 'linear-gradient(90deg,#dc2626 0 100%)' },
  { key: 'usa', label: 'USA', gradient: 'linear-gradient(90deg,#1d4ed8 0 40%,#e11d48 40% 100%)' },
  { key: 'canada', label: 'Canada', gradient: 'linear-gradient(90deg,#c53030 25%,#ffffff 25% 75%,#c53030 75%)' },
  { key: 'argentina', label: 'Argentina', gradient: 'linear-gradient(90deg,#38bdf8 33%,#e5e7eb 33% 66%,#38bdf8 66%)' },
  { key: 'chile', label: 'Chile', gradient: 'linear-gradient(90deg,#1d4ed8 33%,#ffffff 33% 66%,#c53030 66%)' },
  {
    key: 'south africa',
    label: 'South Africa',
    gradient: 'linear-gradient(90deg,#065f46 20%,#111827 20% 40%,#eab308 40% 50%,#e11d48 50% 70%,#1d4ed8 70%)',
  },
  {
    key: 'australia',
    label: 'Australia',
    gradient: 'linear-gradient(135deg,#00205b 44%,#fff 44% 46%,#00205b 46% 54%,#c8102e 54%)'
  },
  {
    key: 'new zealand',
    label: 'New Zealand',
    gradient: 'linear-gradient(135deg,#00205b 70%,#101820 70%), radial-gradient(circle at 20% 30%,#c8102e 0 18%,transparent 18% 21%), radial-gradient(circle at 33% 50%,#c8102e 0 12%,transparent 12% 15%), radial-gradient(circle at 20% 70%,#c8102e 0 12%,transparent 12% 15%), radial-gradient(circle at 35% 80%,#c8102e 0 12%,transparent 12% 15%)'
  },
  { key: 'china', label: 'China', gradient: 'linear-gradient(90deg,#b91c1c 70%,#f59e0b 70%)' },
  { key: 'japan', label: 'Japan', gradient: 'radial-gradient(circle at 50% 50%,#b91c1c 0 40%,#f8fafc 40%)' },
  { key: 'india', label: 'India', gradient: 'linear-gradient(90deg,#f97316 33%,#ffffff 33% 66%,#16a34a 66%)' },
  { key: 'georgia', label: 'Georgia', gradient: 'linear-gradient(5deg,#de2910 30%,#ffffff 30% 70%,#de2910 70%)' },
  { key: 'various', label: 'Various', gradient: 'linear-gradient(90deg,#0f766e 0 25%,#1d4ed8 25% 50%,#7c3aed 50% 75%,#f59e0b 75% 100%)' },
];

export const DEFAULT_FLAG_GRADIENT = 'linear-gradient(#374151,#111827)';

export const getFlagGradient = (origin?: string) => {
  if (!origin) return DEFAULT_FLAG_GRADIENT;
  const lower = origin.toLowerCase();
  const match = FLAG_GRADIENTS.find(({ key }) => lower.includes(key));
  return match ? match.gradient : DEFAULT_FLAG_GRADIENT;
};
