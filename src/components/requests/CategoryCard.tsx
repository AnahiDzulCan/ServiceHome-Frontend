import type { Category } from '../../types/catalog';
import { getCategoryIcon } from '../../utils/categoryIcons';
import '../../styles/components/category-card.css';

interface Props {
  category: Category;
  onSelect: (category: Category) => void;
}

export default function CategoryCard({ category, onSelect }: Props) {
  const Icon = getCategoryIcon(category.nombre);

  return (
    <button type="button" className="category-card" onClick={() => onSelect(category)}>
      <span className="category-card-icon">
        <Icon size={22} strokeWidth={2} />
      </span>
      <span className="category-card-name">{category.nombre}</span>
    </button>
  );
}
