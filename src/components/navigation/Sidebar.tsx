import { HomeOutlined } from '@ant-design/icons';
import type { NavItem } from '../../types/navigation';
import UserCard from './UserCard';

interface Props {
  items: NavItem[];
  activeKey: string;
  onSelect: (key: string) => void;
  user: { initials: string; name: string; detail: string; showStar?: boolean };
}

export default function Sidebar({ items, activeKey, onSelect, user }: Props) {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <span className="sidebar-brand-icon"><HomeOutlined /></span>
        <span className="sidebar-brand-name">ServiceHome</span>
      </div>

      <nav className="sidebar-nav" aria-label="Principal">
        {items.map((item) => (
          <button
            key={item.key}
            type="button"
            className={`sidebar-item${item.key === activeKey ? ' is-active' : ''}`}
            aria-current={item.key === activeKey ? 'page' : undefined}
            onClick={() => onSelect(item.key)}
          >
            <span className="sidebar-item-icon">{item.icon}</span>
            {item.label}
          </button>
        ))}
      </nav>

      <UserCard {...user} />
    </aside>
  );
}