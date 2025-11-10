import './placeholder.css';

interface PlaceholderPageProps {
  title: string;
  description: string;
}

export function PlaceholderPage({ title, description }: PlaceholderPageProps) {
  return (
    <section className="card placeholder-card">
      <p className="eyebrow">قيد البناء</p>
      <h2>{title}</h2>
      <p>{description}</p>
      <ul>
        <li>تجميع مصادر البيانات المطلوبة من API Laravel الحالية.</li>
        <li>تأكيد احتياجات الهوية/الصور/المحتوى لهذا القسم.</li>
        <li>تنفيذ الواجهة وربطها مع سياقات الحالة العامة.</li>
      </ul>
    </section>
  );
}
