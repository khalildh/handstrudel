// A small JSON Schema (2020-12) checker for instrument files, with no
// dependencies so it runs in Deno (Edge Functions) and Node (tests, evals).
// It covers the keywords shared/instruments/schema.json uses and the common
// ones a later format version is likely to add; unknown keywords are ignored.
//
// Generators must follow the schema exactly (shared/instruments/README.md),
// so unlike the app's loader this never repairs: anything out of range fails.

export type Schema = Record<string, unknown>;

export function checkSchema(value: unknown, schema: Schema, root: Schema = schema, path = "$"): string[] {
  const errors: string[] = [];
  check(value, schema, root, path, errors);
  return errors;
}

function resolve(ref: string, root: Schema): Schema {
  if (!ref.startsWith("#/")) throw new Error(`unsupported $ref ${ref}`);
  let node: unknown = root;
  for (const part of ref.slice(2).split("/")) {
    node = (node as Record<string, unknown> | undefined)?.[part.replace(/~1/g, "/").replace(/~0/g, "~")];
  }
  if (!node || typeof node !== "object") throw new Error(`unresolved $ref ${ref}`);
  return node as Schema;
}

function typeOf(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  if (typeof value === "number") return Number.isInteger(value) ? "integer" : "number";
  return typeof value;
}

function typeMatches(value: unknown, type: string) {
  const actual = typeOf(value);
  return actual === type || (type === "number" && actual === "integer");
}

function equal(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

function check(value: unknown, schema: Schema | boolean, root: Schema, path: string, errors: string[]) {
  if (schema === true) return;
  if (schema === false) { errors.push(`${path}: not allowed`); return; }
  if (typeof schema.$ref === "string") check(value, resolve(schema.$ref, root), root, path, errors);

  if (schema.type !== undefined) {
    const types = Array.isArray(schema.type) ? schema.type as string[] : [schema.type as string];
    if (!types.some((t) => typeMatches(value, t))) {
      errors.push(`${path}: expected ${types.join(" or ")}, got ${typeOf(value)}`);
      return;
    }
  }
  if ("const" in schema && !equal(value, schema.const)) {
    errors.push(`${path}: must be ${JSON.stringify(schema.const)}`);
  }
  if (Array.isArray(schema.enum) && !schema.enum.some((option) => equal(option, value))) {
    errors.push(`${path}: must be one of ${schema.enum.map((o) => JSON.stringify(o)).join(", ")}`);
  }

  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) errors.push(`${path}: must be >= ${schema.minimum}`);
    if (typeof schema.maximum === "number" && value > schema.maximum) errors.push(`${path}: must be <= ${schema.maximum}`);
    if (typeof schema.exclusiveMinimum === "number" && value <= schema.exclusiveMinimum) errors.push(`${path}: must be > ${schema.exclusiveMinimum}`);
    if (typeof schema.exclusiveMaximum === "number" && value >= schema.exclusiveMaximum) errors.push(`${path}: must be < ${schema.exclusiveMaximum}`);
    if (!Number.isFinite(value)) errors.push(`${path}: must be finite`);
  }

  if (typeof value === "string") {
    const length = [...value].length;
    if (typeof schema.minLength === "number" && length < schema.minLength) errors.push(`${path}: must have at least ${schema.minLength} characters`);
    if (typeof schema.maxLength === "number" && length > schema.maxLength) errors.push(`${path}: must have at most ${schema.maxLength} characters`);
    if (typeof schema.pattern === "string" && !new RegExp(schema.pattern, "u").test(value)) errors.push(`${path}: must match ${schema.pattern}`);
  }

  if (Array.isArray(value)) {
    if (typeof schema.minItems === "number" && value.length < schema.minItems) errors.push(`${path}: must have at least ${schema.minItems} items`);
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) errors.push(`${path}: must have at most ${schema.maxItems} items`);
    if (schema.uniqueItems === true && new Set(value.map((v) => JSON.stringify(v))).size !== value.length) errors.push(`${path}: items must be unique`);
    const prefix = Array.isArray(schema.prefixItems) ? schema.prefixItems as Schema[] : [];
    value.forEach((item, i) => {
      if (i < prefix.length) check(item, prefix[i], root, `${path}[${i}]`, errors);
      else if (schema.items !== undefined) check(item, schema.items as Schema, root, `${path}[${i}]`, errors);
    });
  }

  if (value && typeof value === "object" && !Array.isArray(value)) {
    const object = value as Record<string, unknown>;
    const properties = (schema.properties ?? {}) as Record<string, Schema>;
    for (const key of (schema.required ?? []) as string[]) {
      if (!(key in object)) errors.push(`${path}: missing required field "${key}"`);
    }
    for (const [key, child] of Object.entries(object)) {
      const childPath = `${path}.${key}`;
      if (key in properties) check(child, properties[key], root, childPath, errors);
      else if (schema.additionalProperties === false) errors.push(`${childPath}: unknown field`);
      else if (schema.additionalProperties && typeof schema.additionalProperties === "object") {
        check(child, schema.additionalProperties as Schema, root, childPath, errors);
      }
    }
    if (typeof schema.minProperties === "number" && Object.keys(object).length < schema.minProperties) errors.push(`${path}: too few fields`);
    if (typeof schema.maxProperties === "number" && Object.keys(object).length > schema.maxProperties) errors.push(`${path}: too many fields`);
  }

  if (Array.isArray(schema.allOf)) for (const part of schema.allOf as Schema[]) check(value, part, root, path, errors);
  for (const keyword of ["anyOf", "oneOf"] as const) {
    const options = schema[keyword];
    if (!Array.isArray(options)) continue;
    const results = (options as Schema[]).map((option) => checkSchema(value, option, root, path));
    const passing = results.filter((r) => r.length === 0).length;
    if (passing === 0) {
      const best = results.reduce((a, b) => (b.length < a.length ? b : a));
      errors.push(...best);
    } else if (keyword === "oneOf" && passing > 1) {
      errors.push(`${path}: matches more than one option`);
    }
  }
  if (schema.not !== undefined && checkSchema(value, schema.not as Schema, root, path).length === 0) {
    errors.push(`${path}: matches a disallowed shape`);
  }
}

/** Keywords the Messages API's structured outputs don't enforce; they are
 *  dropped from the schema sent to the model and checked here afterwards. */
const UNSUPPORTED_FOR_STRUCTURED_OUTPUT = new Set([
  "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf",
  "minLength", "maxLength", "pattern", "minItems", "maxItems", "uniqueItems",
  "minProperties", "maxProperties", "default", "$schema", "$id", "title", "examples", "not",
]);

/** A copy of `schema` the structured-output feature accepts: unsupported
 *  constraints removed, `oneOf` turned into `anyOf`, every object closed. */
export function toStructuredOutputSchema(schema: Schema): Schema {
  const walk = (node: unknown): unknown => {
    if (Array.isArray(node)) return node.map(walk);
    if (!node || typeof node !== "object") return node;
    const out: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(node as Record<string, unknown>)) {
      if (UNSUPPORTED_FOR_STRUCTURED_OUTPUT.has(key)) continue;
      if (key === "properties" || key === "$defs") {
        out[key] = Object.fromEntries(Object.entries(child as Record<string, unknown>).map(([k, v]) => [k, walk(v)]));
      } else {
        out[key === "oneOf" ? "anyOf" : key] = walk(child);
      }
    }
    if (out.type === "object" || out.properties) out.additionalProperties = false;
    return out;
  };
  return walk(schema) as Schema;
}
