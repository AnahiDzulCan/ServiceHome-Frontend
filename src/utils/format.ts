export const fullName = (u: { nombre: string; apellidos: string }) =>
  `${u.nombre} ${u.apellidos}`.trim();

export const initials = (u: { nombre: string; apellidos: string }) =>
  `${u.nombre.charAt(0)}${u.apellidos.charAt(0)}`.toUpperCase();

const pad = (n: number) => String(n).padStart(2, '0');

// Valor para <input type="date"> (YYYY-MM-DD) en hora local, con días de desplazamiento
export function toDateInput(offsetDays = 0): string {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}