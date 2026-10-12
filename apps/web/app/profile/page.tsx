"use client";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
export default function Profile(){const {data,error}=useQuery({queryKey:["me"],queryFn:()=>api<{email:string;display_name?:string;role:string}>("/auth/me")});return <main className="shell max-w-2xl py-12"><p className="eyebrow">Perfil</p><h1 className="mt-2 text-5xl">Tu cuenta</h1>{error?<p className="card mt-8">Inicia sesión para consultar tu perfil.</p>:data&&<div className="card mt-8"><p className="font-semibold">{data.display_name||"Miembro Selah"}</p><p className="mt-1 text-ink/65">{data.email}</p><p className="mt-5 text-xs font-bold tracking-wide text-[#8d743e]">{data.role}</p></div>}</main>}
