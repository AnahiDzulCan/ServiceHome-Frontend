import { useState } from 'react';
import AnnouncementCarousel from '../../components/announcements/AnnouncementCarousel';
import CategoryCard from '../../components/requests/CategoryCard';
import RequestModal from '../../components/requests/RequestModal';
import { mockAnnouncements } from '../../mocks/announcements';
import { mockCategories } from '../../mocks/categories';
import type { Category } from '../../types/catalog';
import '../../styles/pages/client-home.css';

interface Props {
  nombre?: string;
}

export default function ClientHome({ nombre = 'Anahí' }: Props) {
  const [selected, setSelected] = useState<Category | null>(null);
  const [open, setOpen] = useState(false);

  // El saludo va solo en el primer banner
  const items = mockAnnouncements.map((a, i) =>
    i === 0 ? { ...a, eyebrow: `Hola, ${nombre}` } : a,
  );

  const handleSelect = (category: Category) => {
    setSelected(category);
    setOpen(true);
  };

  return (
    <div className="client-home">
      <AnnouncementCarousel items={items} />

      <section>
        <h2 className="section-title">Explorar</h2>
        <div className="category-grid">
          {mockCategories
            .filter((c) => c.activa)
            .map((c) => (
              <CategoryCard key={c.id} category={c} onSelect={handleSelect} />
            ))}
        </div>
      </section>

      <RequestModal category={selected} open={open} onClose={() => setOpen(false)} />
    </div>
  );
}