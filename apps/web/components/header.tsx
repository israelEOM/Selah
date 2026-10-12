"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
export function Header(){const path=usePathname();return <header className="border-b border-ink/10 bg-cream/90"><div className="shell flex h-18 items-center justify-between py-4"><Link href="/" className="leading-none"><span className="font-serif text-3xl font-bold">Selah.</span><span className="ml-2 hidden text-xs text-ink/65 sm:inline">La Palabra que permanece</span></Link><nav className="flex gap-4 text-sm font-medium"><Link href="/library">Biblioteca</Link><Link href="/my-studies">Mi camino</Link><Link href="/admin" className={path.startsWith("/admin")?"text-[#8d743e]":""}>Administrar</Link></nav></div></header>}
