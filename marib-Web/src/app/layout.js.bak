import { Providers } from "@/redux/store/providers";
import "../../public/css/style.css";
import "bootstrap/dist/css/bootstrap.css";
import Head from "next/head";
import { Toaster } from "react-hot-toast";
import 'react-loading-skeleton/dist/skeleton.css'
import Layout from "@/components/Layout/Layout";
import axios from "axios";
// import Script from "next/script";

export const generateMetadata = async () => {
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-system-settings`
    );
    const favicon = response?.data?.data?.favicon_icon
    const placeApiKey = response?.data?.data?.place_api_key
    return {
      icons: [
        {
          url: favicon
        }
      ],
      placeApiKey
    }
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

export default async function RootLayout({ children }) {

  const metadata = await generateMetadata(); // Fetch metadata
  const placeApiKey = metadata?.placeApiKey;



  return (
    <html lang="en" web-version={process.env.NEXT_PUBLIC_WEB_VERSION}>
      <Head>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-9ndCyUaIbzAi2FUVXJi0CjmCapSmO7SnpJef0486qhLnuZ2cdeRhO02iuK6FUUVM" crossOrigin="anonymous" />
        <link rel="stylesheet" href="https://unpkg.com/aos@next/dist/aos.css" />
        <script src="https://js.paystack.co/v1/inline.js"></script>
        <script async defer src={`https://maps.googleapis.com/maps/api/js?key=${placeApiKey}&libraries=places&loading=async`}></script>
      </Head>
      <body>
        {/* <Script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-xxxxxxxxxxxx"
          crossOrigin="anonymous" strategy="afterInteractive" /> */}
        <Providers >
          <Toaster position="top-center" reverseOrder={false} />
          <>
            <Layout>
              {children}
            </Layout>
          </>
        </Providers>
      </body>
    </html>
  );
}

