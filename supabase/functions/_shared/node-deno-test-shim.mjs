// Runs `Deno.test` suites under Node's test runner (Deno isn't required locally):
//   node --import ./supabase/functions/_shared/node-deno-test-shim.mjs --test supabase/functions/_shared/invite-rewards_test.ts
import { test } from "node:test";

globalThis.Deno ??= {
  test: (name, fn) => test(name, fn),
  env: { get: (key) => process.env[key] },
};
