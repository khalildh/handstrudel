"use client";

import dynamic from "next/dynamic";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { isVideoID } from "../../lib/public-feed";

const HandStrudel = dynamic(() => import("../../components/HandStrudel"), {
  ssr: false,
  loading: () => <p className="studio-loading" role="status">Opening the Web Studio...</p>,
});

const PostStudio = dynamic(() => import("./post-studio"), {
  ssr: false,
  loading: () => <p className="studio-loading" role="status">Opening the Web Studio...</p>,
});

/** `/play` is the Web Studio; `/play?v=<postId>` opens it with that post's instrument and sound. */
function StudioRoute() {
  const id = useSearchParams().get("v")?.toLowerCase();
  if (id && isVideoID(id)) return <PostStudio id={id} />;
  return <HandStrudel />;
}

export default function WebInstrument() {
  return (
    <Suspense fallback={<p className="studio-loading" role="status">Opening the Web Studio...</p>}>
      <StudioRoute />
    </Suspense>
  );
}
