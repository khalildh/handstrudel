"use client";

import dynamic from "next/dynamic";

const HandStrudel = dynamic(() => import("../../components/HandStrudel"), {
  ssr: false,
  loading: () => <p className="studio-loading" role="status">Opening the Web Studio...</p>,
});

export default function WebInstrument() {
  return <HandStrudel />;
}
