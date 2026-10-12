import type { Config } from "tailwindcss";
export default { content:["./app/**/*.{ts,tsx}","./components/**/*.{ts,tsx}"], theme:{extend:{colors:{ink:"#14362B",cream:"#F8F3E8",gold:"#C4A66A",sage:"#DCE4D8"},fontFamily:{serif:["Georgia","serif"]}}}, plugins:[] } satisfies Config;
