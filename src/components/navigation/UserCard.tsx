import { StarFilled } from '@ant-design/icons';

interface Props {
  initials: string;
  name: string;
  detail: string;
  showStar?: boolean;
}

export default function UserCard({ initials, name, detail, showStar }: Props) {
  return (
    <div className="user-card">
      <span className="user-card-avatar">{initials}</span>
      <div className="user-card-info">
        <span className="user-card-name">{name}</span>
        <span className="user-card-detail">
          {showStar && <StarFilled className="user-card-star" />}
          {detail}
        </span>
      </div>
    </div>
  );
}