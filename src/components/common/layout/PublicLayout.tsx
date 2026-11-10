import { Outlet } from 'react-router-dom';

export default function LayoutPublico() {
  return (
    <div>
      <header>Header público</header>
      <Outlet />
      <footer>Footer público</footer>
    </div>
  );
}