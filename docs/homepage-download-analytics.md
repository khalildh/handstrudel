# Homepage download analytics

Apply the `20261115010000_homepage_download_clicks.sql` migration before deploying the website. The header, hero, and bottom download links use the App Store Connect `website` campaign. Rebuild with `NEXT_PUBLIC_IOS_APP_STORE_CAMPAIGN_URL` set to a different Apple-generated link if the campaign changes. Safari's native Smart App Banner is not part of this homepage-button campaign.

## Button clicks

In the Supabase SQL Editor, run this query for the days you want to compare:

```sql
select day, sum(clicks) as total_clicks,
       coalesce(sum(clicks) filter (where placement = 'header'), 0) as header_clicks,
       coalesce(sum(clicks) filter (where placement = 'hero'), 0) as hero_clicks,
       coalesce(sum(clicks) filter (where placement = 'footer'), 0) as footer_clicks
from public.homepage_download_clicks
where day >= (now() at time zone 'UTC')::date - 29
group by day
order by day desc;
```

These are counted clicks, not unique visitors. The counter does not store IDs, cookies, IPs, or user agents, but normal infrastructure logs still apply. JavaScript or network blocking can suppress counts, and public counter events are not fraud-proof. No clicks are backfilled.

## Attributed downloads

In App Store Connect, select HandStrudel, then **Analytics > Acquisition > Campaigns > website**. Use **First-Time Downloads** for new downloads rather than redownloads, installs, or first opens. Compare comparable periods and allow for reporting lag and the 24-hour attribution window. Apple hides low-volume campaign metrics; a blank number does not mean zero. See [Apple's campaign reporting rules](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links/).

Apple's separate **Installations** usage metric counts completed installations only for people who share analytics, and includes some repeat installs. It is not a full count of new users. See [Apple's metric definitions](https://developer.apple.com/help/app-store-connect-analytics/reference/metrics-definitions/).

Downloads divided by counted clicks gives a rough aggregate conversion estimate, not a user-level funnel. Keep this link exclusive to the homepage to avoid also attributing downloads from email or social posts.
