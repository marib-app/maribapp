import { Link } from 'react-router-dom';
import './home.css';

const ROADMAP_CARDS = [
  {
    title: 'مرحلة البيانات المفتوحة',
    body: 'بناء صفحات التصفح، البحث، والأقسام باستخدام واجهات API الحالية، مع تجربة RTL كاملة واستجابة للأجهزة المختلفة.',
    badge: 'المرحلة 2',
  },
  {
    title: 'مرحلة الحسابات',
    body: 'توصيل التسجيل، الدخول، صلاحيات المتاجر، وربط جلسات المستخدم بنفس تدفق التطبيق (OTP، الوثائق، تفعيل المتجر).',
    badge: 'المرحلة 3',
  },
  {
    title: 'مرحلة العمليات',
    body: 'لوحة المتجر، إدارة الطلبات، الحملات، الدفعات، والدعم اللحظي لإكمال التطابق مع التجربة داخل التطبيق.',
    badge: 'المرحلة 4',
  },
];

export function HomePage() {
  return (
    <div className="home-grid">
      <section className="card hero-card">
        <p className="eyebrow">مرحلة 1 — الأساس الهندسي</p>
        <h1>تهيئة منصة الويب لتبني كل قدرات التطبيق</h1>
        <p className="lede">
          هذه النسخة تؤسس البنية (React + Vite + TypeScript + React Query + React Router)،
          نظام الثيم، وأطر الربط مع Laravel API. الخطوة التالية هي تغطية جميع الصفحات
          التشغيلية بنفس نطاق التطبيق.
        </p>
        <div className="hero-actions">
          <Link to="/explore" className="btn-primary">
            استعرض المخطط
          </Link>
          <a
            className="btn-ghost"
            href="docs/webapp-phase1.md"
            target="_blank"
            rel="noreferrer"
          >
            وثيقة المرحلة
          </a>
        </div>
      </section>

      <section className="card">
        <h2>لماذا هذه المرحلة؟</h2>
        <ul className="list">
          <li>فصل هوية الويب في مشروع مستقل بدون التأثير على تطبيق Flutter.</li>
          <li>تجهيز مزود بيانات موحد (React Query + Axios) للتحكم في جميع المكالمات.</li>
          <li>تخطيط المسارات الأساسية: التصفح، المتجر، الحساب، والدعم.</li>
        </ul>
      </section>

      <section className="card">
        <h2>مسار التنفيذ القادم</h2>
        <div className="roadmap">
          {ROADMAP_CARDS.map((card) => (
            <article key={card.title}>
              <span className="badge">{card.badge}</span>
              <h3>{card.title}</h3>
              <p>{card.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="card">
        <h2>جاهزية البنية</h2>
        <div className="status-grid">
          <div>
            <strong>✔</strong>
            <span>تنصيب المشروع، ESLint الافتراضي، Vite، TypeScript</span>
          </div>
          <div>
            <strong>✔</strong>
            <span>مزود استعلامات (React Query) وتهيئة Axios مع قاعدة API</span>
          </div>
          <div>
            <strong>✔</strong>
            <span>نظام ملاحة وإطار تصميم يتبع هوية التطبيق</span>
          </div>
          <div>
            <strong>…</strong>
            <span>الربط الكامل بالبيانات (يبدأ في المرحلة الثانية)</span>
          </div>
        </div>
      </section>
    </div>
  );
}
