import "dotenv/config";
const requireEnv = (key) => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing environment variable: ${key}`);
  }
  return value;
};
const parsePort = (value) => {
  const fallback = 8081;
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid PORT value: ${value}`);
  }
  return parsed;
};
export const ENV = {
  SUPABASE_URL: requireEnv("SUPABASE_URL"),
  SUPABASE_ANON_KEY: requireEnv("SUPABASE_ANON_KEY"),
  SUPABASE_SERVICE_ROLE_KEY: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  PORT: parsePort(process.env.PORT),
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS || "http://localhost:3000",
};
//# sourceMappingURL=env.js.map
