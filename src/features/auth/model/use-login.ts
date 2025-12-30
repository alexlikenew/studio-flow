'use client';

import { useMutation } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { createClient } from '../../../shared/api/client/supabase';
import type { LoginFormData } from './schema';

interface LoginError {
  message: string;
}

/**
 * Custom hook for handling user login.
 * Uses React Query's useMutation to handle async authentication.
 *
 * @returns Mutation object with login function and state
 */
export function useLogin() {
  const router = useRouter();
  const supabase = createClient();

  return useMutation({
    mutationFn: async (data: LoginFormData) => {
      const { data: authData, error } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      });

      if (error) {
        throw new Error(error.message);
      }

      return authData;
    },
    onSuccess: () => {
      router.push('/dashboard');
    },
  });
}

