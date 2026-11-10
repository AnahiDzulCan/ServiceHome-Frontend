export interface Announcement {
  id: string;
  eyebrow?: string; // texto pequeño de arriba, ej. "Hola, Anahí"
  title: string;
  text: string;
  image?: string;
  variant?: 'blue' | 'indigo' | 'green';
}