import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";
const isVercel = process.env.VERCEL === "1";

const nextConfig: NextConfig = {
  output: "export",
  basePath: isProd && !isVercel ? "/handstrudel" : "",
  transpilePackages: [
    "@strudel/core",
    "@strudel/webaudio",
    "@strudel/mini",
    "@strudel/tonal",
    "@strudel/soundfonts",
  ],
};

export default nextConfig;
