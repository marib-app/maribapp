import { createBrowserRouter, Navigate } from 'react-router-dom';
import { AppLayout } from '../shared/components/AppLayout';
import { HomePage } from '../pages/HomePage';
import { PlaceholderPage } from '../pages/PlaceholderPage';
import { NotFoundPage } from '../pages/NotFoundPage';

export const router = createBrowserRouter(
  [
    {
      path: '/',
      element: <AppLayout />,
      children: [
        { index: true, element: <HomePage /> },
        {
          path: 'explore',
          element: (
            <PlaceholderPage
              title="التصفح والاكتشاف"
              description="قريباً ستتمكن من تصفح كل الأقسام، الفلاتر، والخرائط كما في التطبيق الأصلي."
            />
          ),
        },
        {
          path: 'merchants',
          element: (
            <PlaceholderPage
              title="لوحة التاجر"
              description="بناء لوحة متابعة الطلبات، الحملات، والدفعات الخاصة بالمتاجر ضمن الويب."
            />
          ),
        },
        {
          path: 'auth',
          element: (
            <PlaceholderPage
              title="التسجيل وتسجيل الدخول"
              description="سيتم توصيل جميع خطوات التسجيل (OTP، الهوية، الربط بالمتجر) هنا."
            />
          ),
        },
        {
          path: 'support',
          element: (
            <PlaceholderPage
              title="الدعم والمراسلات"
              description="قنوات المحادثة المباشرة، فتح التذاكر، وتتبع المحادثات سيتم توفيرها في هذه المساحة."
            />
          ),
        },
        {
          path: 'app',
          element: <Navigate to="/" replace />,
        },
        { path: '*', element: <NotFoundPage /> },
      ],
    },
  ],
  { basename: import.meta.env.BASE_URL },
);
