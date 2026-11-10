import type { ReactNode } from 'react';

export interface NavItem {
  key: string; // luego será la ruta, por ejemplo /cliente/solicitudes
  label: string;
  icon: ReactNode;
}
