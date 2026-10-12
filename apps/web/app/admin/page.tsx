"use client";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
type Sermon={id:number;original_title?:string;suggested_title?:string;status:string;thumbnail_url?:string};
export default function Admin(){const {data,error,refetch}=useQuery({queryKey:["sermons"],queryFn:()=>api<Sermon[]>("/sermons")});return <main className="shell py-12"><div className="flex items-end justify-between"><div><p className="eyebrow">Administración</p><h1 className="mt-2 text-5xl">Predicaciones</h1></div><Link className="button" href="/admin/sermons/new">Importar sermón</Link></div>{error?<p className="card mt-8">{error.message} <Link className="underline" href="/login">Iniciar sesión</Link></p>:<div className="mt-9 grid gap-4">{data?.map(s=><Link href={`/admin/sermons/${s.id}`} key={s.id} className="card flex items-center justify-between hover:border-gold"><span><span className="font-serif text-xl">{s.suggested_title||s.original_title||"Sin título"}</span><span className="ml-4 text-xs font-bold text-[#8d743e]">{s.status.replaceAll("_"," ")}</span></span><span>→</span></Link>)}</div>}</main>}
