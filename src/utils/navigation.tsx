import {
  FileTextOutlined,
  HomeOutlined,
  ProfileOutlined,
  TeamOutlined,
  ToolOutlined,
  UserOutlined,
  BarChartOutlined,
} from '@ant-design/icons';
import type { NavItem } from '../types/navigation';
import type { Role } from '../types/user';

export const navItems: Record<Role, NavItem[]> = {
  cliente: [
    { key: '/cliente/inicio', label: 'Inicio', icon: <HomeOutlined /> },
    { key: '/cliente/solicitudes', label: 'Mis pedidos', icon: <ProfileOutlined /> },
    { key: '/cliente/perfil', label: 'Perfil', icon: <UserOutlined /> },
  ],
  tecnico: [
    { key: '/tecnico/inicio', label: 'Inicio', icon: <HomeOutlined /> },
    { key: '/tecnico/solicitudes', label: 'Mis solicitudes', icon: <ProfileOutlined /> },
    { key: '/tecnico/perfil', label: 'Perfil', icon: <UserOutlined /> },
  ],
  admin: [
    { key: '/admin/inicio', label: 'Inicio', icon: <HomeOutlined /> },
    { key: '/admin/usuarios', label: 'Usuarios', icon: <TeamOutlined /> },
    { key: '/admin/tecnicos', label: 'Técnicos', icon: <ToolOutlined /> },
    { key: '/admin/facturas', label: 'Facturas', icon: <FileTextOutlined /> },
    { key: '/admin/reportes', label: 'Reportes', icon: <BarChartOutlined /> },
  ],
};

export const roleLabel: Record<Role, string> = {
  cliente: 'Cliente',
  tecnico: 'Técnico',
  admin: 'Administrador',
};