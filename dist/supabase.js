import { createClient } from '@supabase/supabase-js';
import { ENV } from './env.js';
export const supabaseAdmin = createClient(ENV.SUPABASE_URL, ENV.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
export const supabaseAnon = createClient(ENV.SUPABASE_URL, ENV.SUPABASE_ANON_KEY, { auth: { persistSession: false } });
//# sourceMappingURL=supabase.js.map