import { Providers } from "@/redux/store/providers";
import "../../public/css/style.css";
import "bootstrap/dist/css/bootstrap.css";
import { Toaster } from "react-hot-toast";
import 'react-loading-skeleton/dist/skeleton.css'
import Layout from "@/components/Layout/Layout";
import Script from "next/script";

export async function generateMetadata() {
  try {
    const res = await fetch(\\\get-system-settings\, { cache: "no-store" });
    const data = await res.json();
    const favicon = data?.data?.favicon_icon;
    return {
      icons: favicon ? [{ url: favicon }] : undefined,
    };
  } catch {
    return {};
  }
}

export default function RootLayout({ children }) {
  const placeApiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";
  return (
    <html lang="ar" suppressHydrationWarning>
      <head>
        <link rel="stylesheet" href="https://unpkg.com/aos@next/dist/aos.css" />
      </head>
      <body>
        <Script src="https://js.paystack.co/v1/inline.js" strategy="afterInteractive" />
        {placeApiKey ? (
          <Script
            src={\https://maps.googleapis.com/maps/api/js?key=\&libraries=places\}
            strategy="afterInteractive"
          />
        ) : null}
        <Providers>
          <Toaster position="top-center" reverseOrder={false} />
          <Layout>{children}</Layout>
        </Providers>
      </body>
    </html>
  );
}
