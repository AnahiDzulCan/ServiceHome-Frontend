import electricianImg from '../assets/images/banner-electrician.png';
import type { Announcement } from '../types/announcement';

export const mockAnnouncements: Announcement[] = [
  {
    id: '1',
    title: 'Los mejores servicios para ti',
    text: 'Encuentra profesionales de confianza para electricidad, plomería y jardinería, y más.',
    image: electricianImg,
    variant: 'blue',
  },
  {
    id: '2',
    eyebrow: 'Tu tranquilidad primero',
    title: 'Técnicos verificados',
    text: 'Cada profesional es revisado por nuestro equipo antes de recibir solicitudes.',
    variant: 'indigo',
  },
  {
    id: '3',
    eyebrow: 'Tu opinión cuenta',
    title: 'Califica tu servicio',
    text: 'Al finalizar un trabajo podrás revisar la factura y calificar al técnico.',
    variant: 'green',
  },
];