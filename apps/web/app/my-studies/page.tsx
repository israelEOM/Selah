"use client";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
export default function MyStudies(){const {data,error}=useQuery({queryKey:["progress"],queryFn:()=>api<{study_id:number;day_number:number;completed_at:string}[]>("/me/progress")});return <main className="shell py-12"><p className="eyebrow">Mi camino</p><h1 className="mt-2 text-5xl">Pequeños pasos de fe.</h1>{error?<p className="mt-8 card">Inicia sesión para ver tu progreso.</p>:<div className="mt-8 space-y-3">{data?.length?data.map(x=><div className="card" key={`${x.study_id}-${x.day_number}`}>Estudio {x.study_id} · Día {x.day_number} completado</div>):<p className="text-ink/65">Todavía no has completado ningún día.</p>}</div>}</main>}
