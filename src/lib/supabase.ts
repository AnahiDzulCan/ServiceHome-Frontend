import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/supabase';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error(
    'Faltan variables de entorno de Supabase. Revisa VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY en .env.local'
  );
}

export const supabase = createClient<Database>(supabaseUrl, supabaseKey);