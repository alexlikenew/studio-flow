'use client';

import { createBrowserClient } from '@supabase/ssr';

/**
 * Creates a Supabase client for use in Client Components.
 * This client uses browser-based storage and should only be used in 'use client' components.
 *
 * @returns A Supabase client instance configured for browser usage
 */
export function createClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing Supabase environment variables. Please check your .env.local file.'
    );
  }

  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}


