import { Link, NavLink } from 'react-router-dom';
import './app-header.css';

const NAV_LINKS = [
  { to: '/', label: 'الرئيسية' },
  { to: '/explore', label: 'التصفح' },
  { to: '/merchants', label: 'المتاجر' },
  { to: '/auth', label: 'الحساب' },
  { to: '/support', label: 'الدعم' },
];

interface AppHeaderProps {
  activePath: string;
}

export function AppHeader({ activePath }: AppHeaderProps) {
  return (
    <header className="app-header">
      <div className="brand">
        <Link to="/">
          <span className="brand-mark">مـ</span>
          <div>
            <strong>منصة مأرب</strong>
            <small>هوية التطبيق على الويب</small>
          </div>
        </Link>
      </div>

      <nav className="main-nav">
        {NAV_LINKS.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            className={({ isActive }) => (isActive || activePath === link.to ? 'is-active' : '')}
          >
            {link.label}
          </NavLink>
        ))}
      </nav>

      <a
        className="cta-button"
        href="https://merchant.marib.app"
        target="_blank"
        rel="noreferrer"
      >
        لوحة التطبيق
      </a>
    </header>
  );
}
