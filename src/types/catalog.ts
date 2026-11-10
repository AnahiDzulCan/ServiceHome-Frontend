export interface Category {
  id: number;
  nombre: string;
  descripcion: string | null;
  activa: boolean;
  mano_obra_max: number | null;
}
