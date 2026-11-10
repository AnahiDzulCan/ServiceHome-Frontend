import { useState, type ReactNode } from 'react';
import BottomNav from '../components/navigation/BottomNav';
import Sidebar from '../components/navigation/Sidebar';
import { fullName, initials } from '../utils/format';
import { navItems, roleLabel } from '../utils/navigation';
import type { Role } from '../types/user';
import '../styles/components/navigation.css';

interface Props {
  role: Role;
  user: { nombre: string; apellidos: string; calificacion?: number | null };
  activeKey?: string;
  onNavigate?: (key: string) => void;
  children: ReactNode;
}

export default function PanelLayout({ role, user, activeKey, onNavigate, children }: Props) {
  const items = navItems[role];
  const [localKey, setLocalKey] = useState(items[0].key);

  const current = activeKey ?? localKey;
  const select = (key: string) => {
    setLocalKey(key);
    onNavigate?.(key);
  };

  const isTechnician = role === 'tecnico';
  const detail = isTechnician
    ? user.calificacion != null
      ? user.calificacion.toFixed(1)
      : 'Sin calificación'
    : roleLabel[role];

  return (
    <div className="app-shell">
      <Sidebar
        items={items}
        activeKey={current}
        onSelect={select}
        user={{ initials: initials(user), name: fullName(user), detail, showStar: isTechnician }}
      />
      <main className="app-main">{children}</main>
      <BottomNav items={items} activeKey={current} onSelect={select} />
    </div>
  );
}