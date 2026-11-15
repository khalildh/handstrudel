export const appStoreId = "6764415289";
export const appStoreUrl = `https://apps.apple.com/app/id${appStoreId}`;
const websiteCampaign = `https://apps.apple.com/app/apple-store/id${appStoreId}?pt=127873492&ct=website&mt=8`;

export function homepageAppStoreUrl(campaign = process.env.NEXT_PUBLIC_IOS_APP_STORE_CAMPAIGN_URL || websiteCampaign): string {
  try {
    const url = new URL(campaign);
    const provider = url.searchParams.get("pt");
    const token = url.searchParams.get("ct");
    if (url.origin === "https://apps.apple.com" && !url.username && !url.password &&
        url.pathname.split("/").includes("app") &&
        url.pathname.replace(/\/$/, "").endsWith(`/id${appStoreId}`) &&
        provider && /^\d+$/.test(provider) && token?.trim() && token.length <= 30 &&
        url.searchParams.get("mt") === "8") {
      return url.href;
    }
  } catch {
    // A missing or invalid campaign must not break the download link.
  }
  return appStoreUrl;
}
