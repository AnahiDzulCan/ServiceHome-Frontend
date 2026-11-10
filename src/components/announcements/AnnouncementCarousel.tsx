import { Carousel } from 'antd';
import type { Announcement } from '../../types/announcement';
import '../../styles/components/announcements.css';

interface Props {
  items: Announcement[];
}

export default function AnnouncementCarousel({ items }: Props) {
  return (
    <Carousel autoplay autoplaySpeed={6000} pauseOnHover className="announcement-carousel">
      {items.map((item) => (
        <div key={item.id}>
          <article
            className={`banner banner-${item.variant ?? 'blue'}${item.image ? ' has-image' : ''}`}
          >
            {item.image && <img className="banner-image" src={item.image} alt="" />}
            <div className="banner-content">
              {item.eyebrow && <p className="banner-eyebrow">{item.eyebrow}</p>}
              <h2 className="banner-title">{item.title}</h2>
              <p className="banner-text">{item.text}</p>
            </div>
          </article>
        </div>
      ))}
    </Carousel>
  );
}