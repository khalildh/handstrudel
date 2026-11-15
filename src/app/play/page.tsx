import type { Metadata } from "next";
import WebInstrument from "./web-instrument";

export const metadata: Metadata = {
  title: "HandStrudel Web Studio",
  description: "Play HandStrudel's hand-tracking musical instrument in your browser.",
};

export default function PlayPage() {
  return <WebInstrument />;
}
