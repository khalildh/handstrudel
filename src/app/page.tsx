"use client";

import dynamic from "next/dynamic";

const HandStrudel = dynamic(() => import("../components/HandStrudel"), {
  ssr: false,
});

export default function Home() {
  return <HandStrudel />;
}
