import type { Category } from '../types/catalog';

export const mockCategories: Category[] = [
  { id: 1, nombre: 'Plomería', descripcion: 'Reparación de fugas y tuberías', activa: true, mano_obra_max: null },
  { id: 3, nombre: 'Jardinería', descripcion: 'Poda y mantenimiento de áreas verdes', activa: true, mano_obra_max: null },
  { id: 2, nombre: 'Electricidad', descripcion: 'Instalaciones, cortos y contactos', activa: true, mano_obra_max: null },
];
