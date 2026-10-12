"use client";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { api, bibleReader, youtubeMoment } from "@/lib/api";
type Day={id:number;day_number:number;title:string;main_reference:string;content:{central_teaching:string;reflection:string;practical_application:string;questions:string[];suggested_prayer:string;source_timestamp_seconds?:number;estimated_reading_minutes:number}};type Study={id:number;slug:string;title:string;sermon:{youtube_video_id:string};days:Day[]};
export default function Reader(){
  const {slug,number}=useParams<{slug:string;number:string}>();
  const {data}=useQuery({queryKey:["study",slug],queryFn:()=>api<Study>(`/public/studies/${slug}`)});
  if(!data)return <main className="shell py-16">Cargando…</main>;
  const study=data;
  const day=study.days.find(x=>x.day_number===Number(number));
  if(!day)return <main className="shell py-16">Día no encontrado.</main>;
  const selectedDay=day;
  async function done(){try{await api("/me/progress",{method:"POST",body:JSON.stringify({study_id:study.id,day_number:selectedDay.day_number})});alert("Día marcado como completado.")}catch(e){alert(e instanceof Error?e.message:"Inicia sesión para guardar tu progreso.")}}
  return <main className="shell max-w-3xl py-12"><Link className="text-sm text-ink/60" href={`/studies/${slug}`}>← Volver al estudio</Link><p className="eyebrow mt-9">Día {selectedDay.day_number} · {selectedDay.content.estimated_reading_minutes} min</p><h1 className="mt-2 text-5xl">{selectedDay.title}</h1><a className="mt-5 inline-flex font-serif text-xl text-[#8d743e] underline decoration-gold underline-offset-4" href={bibleReader(selectedDay.main_reference)} target="_blank" rel="noreferrer">Leer {selectedDay.main_reference} en RVR1960 ↗</a><p className="mt-2 text-xs text-ink/55">La lectura se abre en un lector externo; Selah no almacena texto bíblico.</p><section className="mt-10 border-l-2 border-gold pl-5"><p className="text-sm font-bold uppercase tracking-wide">Enfoque</p><p className="mt-2 text-xl leading-8">{selectedDay.content.central_teaching}</p></section><article className="mt-10 prose prose-lg max-w-none text-ink"><h2>Reflexión</h2><p className="whitespace-pre-line leading-8">{selectedDay.content.reflection}</p><h2>Para practicar hoy</h2><p className="leading-8">{selectedDay.content.practical_application}</p><h2>Para reflexionar</h2><ol className="space-y-2">{selectedDay.content.questions.map((q,i)=><li key={i}>{q}</li>)}</ol><h2>Oración sugerida</h2><p className="whitespace-pre-line italic leading-8">{selectedDay.content.suggested_prayer}</p><p className="not-prose mt-6 rounded-xl bg-sage/50 p-4 text-sm">Esta oración es material devocional sugerido por Selah; no es una cita del predicador.</p></article>{selectedDay.content.source_timestamp_seconds!==undefined&&<a className="button-secondary mt-8" target="_blank" href={youtubeMoment(study.sermon.youtube_video_id,selectedDay.content.source_timestamp_seconds)}>Escuchar este momento</a>}<button onClick={done} className="button mt-8 w-full">Marcar día como completado</button></main>
}
