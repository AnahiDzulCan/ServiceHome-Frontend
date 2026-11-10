import type { ReactNode } from 'react';
import '../../styles/components/auth-card.css';

interface Props {
  icono: ReactNode;
  titulo: string;
  subtitulo: string;
  pie?: ReactNode;
  anchoMaximo?: number;
  children: ReactNode;
}

export default function TarjetaAuth({
  icono,
  titulo,
  subtitulo,
  pie,
  anchoMaximo = 420,
  children,
}: Props) {
  return (
    <main className="auth-page">
      <section className="auth-card fade-in" style={{ maxWidth: anchoMaximo }}>
        <div className="auth-icon">{icono}</div>
        <h1 className="auth-title">{titulo}</h1>
        <p className="auth-subtitle">{subtitulo}</p>
        {children}
        {pie && <p className="auth-footer">{pie}</p>}
      </section>
    </main>
  );
}