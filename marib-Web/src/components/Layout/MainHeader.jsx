'use client'
import { usePathname } from "next/navigation"
import LandingPageHeader from "./LandingPageHeader"
import Header from "./Header"



const MainHeader = ({nor}) => {
  const pathname = usePathname()

  return (
    <>
      {pathname === '/home' ? (
        <LandingPageHeader />
      )
        : (
          <Header />
        )}
    </>
  )
}

export default MainHeader