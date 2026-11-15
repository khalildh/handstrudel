import Link from "next/link";

const pages = [
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
];

export function SiteInfoLinks({ current }: { current?: string }) {
  return (
    <nav aria-label="Site information">
      <ul className="site-info-links" role="list">
        {pages.map(({ href, label }, i) => (
          <li key={href}>
            {i > 0 && <span aria-hidden="true">{" / "}</span>}
            <Link href={href} aria-current={current === href ? "page" : undefined}>{label}</Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
