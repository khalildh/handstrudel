-- Qualify the outer source ID: feed_videos also has a source_video_id column.
alter policy "read active challenges with a visible opted-in source" on public.weekly_challenges
using (featured and starts_at <= now() and ends_at > now() and exists (
  select 1 from public.feed_videos v where v.id = weekly_challenges.source_video_id and v.backing_enabled
));
