import { LoginForm } from '../../../features/auth/ui/LoginForm';

/**
 * Login page for Creator authentication.
 * Displays a centered login form.
 */
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <LoginForm />
    </div>
  );
}

