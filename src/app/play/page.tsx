import type { Metadata } from "next";
import WebInstrument from "./web-instrument";
import "./studio.css";

export const metadata: Metadata = {
  title: "HandStrudel Web Studio",
  description: "Play HandStrudel's hand-tracking musical instrument in your browser.",
};
export const viewport = { themeColor: "#f7f6f1" };

export default function PlayPage() {
  return <WebInstrument />;
}
