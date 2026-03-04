import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";

const nextConfig: NextConfig = {
  output: "export",
  basePath: isProd ? "/handstrudel" : "",
  transpilePackages: [
    "@strudel/core",
    "@strudel/webaudio",
    "@strudel/mini",
    "@strudel/tonal",
  ],
};

export default nextConfig;
