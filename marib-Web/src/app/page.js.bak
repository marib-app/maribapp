import HomePage from '@/components/Home';

export async function generateMetadata() {
  try {
    const res = await fetch(\\\seo-settings?page=home\, { cache: "no-store" });
    const data = await res.json();
    const title = data?.title || process.env.NEXT_PUBLIC_META_TITLE || "Marib";
    return { title };
  } catch {
    return { title: process.env.NEXT_PUBLIC_META_TITLE || "Marib" };
  }
}

export default function Page() {
  return <HomePage />;
}
