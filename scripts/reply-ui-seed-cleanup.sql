-- LOCAL ONLY. Removes the rows added by reply-ui-seed.sql.
delete from public.videos where id::text like '7b000000-%';
delete from public.pending_video_uploads where id::text like '7b000000-%';
delete from auth.users where id::text like '7a000000-%';
