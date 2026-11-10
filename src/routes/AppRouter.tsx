import { Routes, Route } from 'react-router-dom';
import Login from '../pages/public/Login.tsx';
import SeleccionRol from '../pages/public/RoleSelection.tsx';
import PanelLayout from '../layouts/PanelLayout.tsx';
import ClientHome from '../pages/client/ClientHome.tsx';

export default function AppRouter() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/seleccionRol" element={<SeleccionRol />} />
      <Route
        path="/cliente/inicio"
        element={
          <PanelLayout role="cliente" user={{ nombre: 'Anahí', apellidos: 'Dzul' }}>
            <ClientHome nombre="Anahí" />
          </PanelLayout>
        }
      />
      <Route
        path="/cliente/*"
        element={
          <PanelLayout role="cliente" user={{ nombre: 'Anahí', apellidos: 'Dzul' }}>
            <h2>Panel de cliente</h2>
          </PanelLayout>
        }
      />
      <Route
        path="/tecnico/*"
        element={
          <PanelLayout
            role="tecnico"
            user={{ nombre: 'Anahí', apellidos: 'Dzul', calificacion: null }}
          >
            <h2>Panel de técnico</h2>
          </PanelLayout>
        }
      />
    </Routes>
  );
}
