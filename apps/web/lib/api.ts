const API=process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
export async function api<T>(path:string, init:RequestInit={}) : Promise<T> {
  const token=typeof window!=="undefined"?localStorage.getItem("selah_token"):null;
  const response=await fetch(`${API}${path}`,{...init,credentials:"include",headers:{"Content-Type":"application/json",...(token?{Authorization:`Bearer ${token}`}:{}) ,...init.headers}});
  if(!response.ok) { const data=await response.json().catch(()=>({})); throw new Error(data.detail || "No fue posible completar esta acción."); }
  return response.status===204 ? undefined as T : response.json();
}
export function youtubeMoment(videoId:string,seconds:number) { return `https://www.youtube.com/watch?v=${videoId}&t=${Math.max(0,Math.round(seconds))}s`; }
export function bibleReader(reference:string, version="RVR1960") { return `https://www.biblegateway.com/passage/?${new URLSearchParams({search:reference,version}).toString()}`; }
