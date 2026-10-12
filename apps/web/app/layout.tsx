import "./globals.css";
import { Providers } from "@/components/providers";
import { Header } from "@/components/header";
export const metadata={title:"Selah — La Palabra que permanece",description:"Estudios y devocionales nacidos de la predicación."};
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="es"><body><Providers><Header/>{children}</Providers></body></html> }
