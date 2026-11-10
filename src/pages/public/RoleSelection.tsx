import { LoginOutlined, ToolOutlined, UserOutlined } from '@ant-design/icons';
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import TarjetaAuth from '../../components/ui/AuthCard.tsx';
import '../../styles/pages/role-selection.css';

interface OpcionRol {
  etiqueta: string;
  icono: ReactNode;
  destino: string;
}

const opciones: OpcionRol[] = [
  { etiqueta: 'Cliente', icono: <UserOutlined />, destino: '/cliente/inicio' },
  { etiqueta: 'Técnico', icono: <ToolOutlined />, destino: '/tecnico/inicio' },
]

export default function SeleccionRol() {
  const navigate = useNavigate();

  return (
    <TarjetaAuth
      icono={<LoginOutlined />}
      titulo="Elige tu rol"
      subtitulo="Selecciona cómo deseas ingresar"
      anchoMaximo={560}
    >
      <div className="rol-opciones">
        {opciones.map((o) => (
          <button
            key={o.etiqueta}
            type="button"
            className="rol-opcion"
            onClick={() => navigate(o.destino)}
          >
            <span className="rol-opcion-icono">{o.icono}</span>
            <span className="rol-opcion-texto">{o.etiqueta}</span>
          </button>
        ))}
      </div>
    </TarjetaAuth>
  );
}