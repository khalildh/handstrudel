import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";
const isVercel = process.env.VERCEL === "1";
const basePath = isProd && !isVercel ? "/handstrudel" : "";

const nextConfig: NextConfig = {
  output: "export",
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  transpilePackages: [
    "@strudel/core",
    "@strudel/webaudio",
    "@strudel/mini",
    "@strudel/tonal",
    "@strudel/soundfonts",
  ],
};

export default nextConfig;
