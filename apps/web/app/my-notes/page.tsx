"use client";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
export default function MyNotes(){const {data,error}=useQuery({queryKey:["notes"],queryFn:()=>api<{id:number;content:string;updated_at:string}[]>("/me/notes")});return <main className="shell max-w-3xl py-12"><p className="eyebrow">Notas privadas</p><h1 className="mt-2 text-5xl">Lo que el Señor te mostró.</h1>{error?<p className="card mt-8">Inicia sesión para consultar tus notas.</p>:<div className="mt-8 space-y-4">{data?.length?data.map(note=><article className="card" key={note.id}><p className="whitespace-pre-line leading-7">{note.content}</p></article>):<p className="text-ink/65">Las notas que guardes mientras lees aparecerán aquí.</p>}</div>}</main>}
