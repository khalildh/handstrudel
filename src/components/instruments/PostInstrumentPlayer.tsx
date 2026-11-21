"use client";

// Resolves a shared post's instrument and sound, then hands them to the player
// for the instrument's surface type.

import { useEffect, useMemo, useState } from "react";
import { choosePostInstrument, fetchPostInstrumentSpec, type PostInstrument } from "../../lib/instruments/post-instrument";
import { resolveWheelSound } from "../../lib/instruments/sound";
import type { InstrumentSpec } from "../../lib/instruments/spec";
import InstrumentPlayer from "./InstrumentPlayer";

export interface PlayablePost {
  id: string;
  username: string;
  sound_setup?: unknown;
  /** From the feed: the post carries an instrument file. */
  has_instrument?: boolean;
  /** The file itself, when the row already includes it. */
  instrument_spec?: unknown;
}

interface Props {
  post: PlayablePost;
  cameraFirst?: boolean;
  audioStarted?: boolean;
  onClose?: () => void;
}

export default function PostInstrumentPlayer({ post, cameraFirst, audioStarted, onClose }: Props) {
  const sound = useMemo(() => resolveWheelSound(post.sound_setup), [post.sound_setup]);
  const mode = sound.mode;
  const [instrument, setInstrument] = useState<PostInstrument | null>(() =>
    post.instrument_spec !== undefined || !post.has_instrument ? choosePostInstrument(post.instrument_spec, mode) : null);

  useEffect(() => {
    if (post.instrument_spec !== undefined || !post.has_instrument) {
      setInstrument(choosePostInstrument(post.instrument_spec, mode));
      return;
    }
    const request = new AbortController();
    setInstrument(null);
    fetchPostInstrumentSpec(post.id, request.signal).then((spec) => {
      if (!request.signal.aborted) setInstrument(choosePostInstrument(spec, mode));
    });
    return () => request.abort();
  }, [post.id, post.has_instrument, post.instrument_spec, mode]);

  if (!instrument) return <p className="watch-player-loading" role="status">Loading the instrument…</p>;
  const note = instrument.source === "post"
    ? `Instrument from @${post.username}’s post`
    : instrument.rejected
      ? instrument.rejected.includes("unsupported_version")
        ? `This post’s instrument isn’t playable on the web yet, so it plays on the built-in ${instrument.spec.name}.`
        : `This post’s instrument couldn’t be opened, so it plays on the built-in ${instrument.spec.name}.`
      : `Built-in ${instrument.spec.name}, as in @${post.username}’s performance`;
  return renderSurface(instrument.spec, {
    sound, instrumentNote: note, cameraFirst, audioStarted, onClose,
  });
}

/** One player per surface type. Format v2 surfaces (grids, keys, pads, arcs, orbs) add cases here. */
function renderSurface(spec: InstrumentSpec, props: Omit<Parameters<typeof InstrumentPlayer>[0], "spec">) {
  switch (spec.surface.type) {
    case "split_wheel":
      return <InstrumentPlayer key={spec.id} spec={spec} {...props} />;
  }
}
