"use client";

interface HeaderProps {
  status: string;
}

export default function Header({ status }: HeaderProps) {
  return (
    <div id="header">
      <span className="logo">HANDSTRUDEL</span>
      <span className="sep">|</span>
      <span id="status">{status}</span>
      <div id="beat-row">
        <div className="bd" id="bd0" />
        <div className="bd" id="bd1" />
        <div className="bd" id="bd2" />
        <div className="bd" id="bd3" />
      </div>
    </div>
  );
}
