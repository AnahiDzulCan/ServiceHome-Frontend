import type { NavItem } from '../../types/navigation';

interface Props {
  items: NavItem[];
  activeKey: string;
  onSelect: (key: string) => void;
}

export default function BottomNav({ items, activeKey, onSelect }: Props) {
  return (
    <nav className="bottom-nav" aria-label="Principal">
      {items.map((item) => (
        <button
          key={item.key}
          type="button"
          className={`bottom-nav-item${item.key === activeKey ? ' is-active' : ''}`}
          aria-current={item.key === activeKey ? 'page' : undefined}
          onClick={() => onSelect(item.key)}
        >
          <span className="bottom-nav-icon">{item.icon}</span>
          <span className="bottom-nav-label">{item.label}</span>
        </button>
      ))}
    </nav>
  );
}