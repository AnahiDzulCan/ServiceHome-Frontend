import { Droplets, Leaf, Wrench, Zap, type LucideIcon } from 'lucide-react';

const icons: Record<string, LucideIcon> = {
  Plomería: Droplets,
  Jardinería: Leaf,
  Electricidad: Zap,
};

export function getCategoryIcon(name: string): LucideIcon {
  return icons[name] ?? Wrench;
}
