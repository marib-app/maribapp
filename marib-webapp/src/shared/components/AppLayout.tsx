import { Outlet, useLocation } from 'react-router-dom';
import { AppHeader } from './AppHeader';

export function AppLayout() {
  const location = useLocation();

  return (
    <div className="app-shell">
      <AppHeader activePath={location.pathname} />
      <main className="app-content">
        <Outlet />
      </main>
      <footer style={{ padding: '1.5rem', textAlign: 'center', color: 'var(--color-muted)' }}>
        منصة مأرب © {new Date().getFullYear()} — نسخة الويب قيد التطوير.
      </footer>
    </div>
  );
}
