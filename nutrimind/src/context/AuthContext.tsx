"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { usePathname } from "next/navigation";

/**
 * Auth context. Recognises two storage backends so the landing page stays in
 * sync with the dashboard after navigation:
 *
 *   1. The server route at /api/auth/me reads the request's `Cookie` header
 *      (HttpOnly session cookies ARE visible to a server route even when
 *      they're invisible to `document.cookie` in the browser).
 *
 *   2. The dashboard layout stores its session token in
 *      `localStorage.getItem("nutrimind_token")` — the landing page reads
 *      that too so a NutriMind-logo click on /dashboard/* doesn't make the
 *      user look signed-out when they come back to /.
 *
 * Either side authenticating is enough for the UI to flip "Sign In" →
 * "Sign Out". The actual session validation still happens on the backend,
 * so any spoofing here is rejected by the real protected routes.
 */

interface AuthContextValue {
  isAuthenticated: boolean;
  isLoading: boolean;
  signIn: () => void;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  isAuthenticated: false,
  isLoading: true,
  signIn: () => {},
  signOut: async () => {},
});

const COOKIE_HINT_NAMES = [
  "session",
  "auth_token",
  "token",
  "nutrimind_session",
];

const LOCAL_STORAGE_AUTH_KEYS = [
  "nutrimind_token",
  "auth_token",
];

function cookieHintSaysAuthed(): boolean {
  if (typeof document === "undefined") return false;
  const jar = document.cookie ?? "";
  return COOKIE_HINT_NAMES.some((name) =>
    jar.split("; ").some((c) => c.startsWith(`${name}=`)),
  );
}

function localStorageSaysAuthed(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return LOCAL_STORAGE_AUTH_KEYS.some((key) => {
      const value = window.localStorage.getItem(key);
      return !!value && value !== "null" && value !== "undefined";
    });
  } catch {
    // Storage access can throw in private-browsing / strict-storage modes.
    return false;
  }
}

function clearLocalAuthHints() {
  if (typeof document === "undefined") return;
  const expires = "Thu, 01 Jan 1970 00:00:00 GMT";
  for (const name of COOKIE_HINT_NAMES) {
    document.cookie = `${name}=; expires=${expires}; path=/`;
  }
  if (typeof window !== "undefined" && window.localStorage) {
    for (const key of LOCAL_STORAGE_AUTH_KEYS) {
      try {
        window.localStorage.removeItem(key);
      } catch {
        // ignore
      }
    }
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const pathname = usePathname();

  useEffect(() => {
    let cancelled = false;

    // Optimistic first paint — either storage backend with a token wins.
    if (cookieHintSaysAuthed() || localStorageSaysAuthed()) {
      setIsAuthenticated(true);
    }

    // Authoritative check via the server route, which reads the Cookie
    // header (so HttpOnly cookies are visible to it even when they're not
    // to `document.cookie`).
    (async () => {
      try {
        const res = await fetch("/api/auth/me", {
          method: "GET",
          credentials: "include",
          cache: "no-store",
        });
        if (cancelled) return;
        if (res.ok) {
          const data = (await res.json()) as { authenticated?: boolean };
          if (data.authenticated) {
            setIsAuthenticated(true);
            return;
          }
        }
        // Server route either didn't return ok or said `authenticated: false`.
        // Fall back to the localStorage check — if the dashboard stored a
        // token there, the landing page still shows "Sign Out".
        if (localStorageSaysAuthed()) {
          setIsAuthenticated(true);
        } else {
          setIsAuthenticated(false);
        }
      } catch {
        if (cancelled) return;
        // Network failure — don't kick the user out if the local signal
        // disagrees. Stay optimistic until next mount.
        if (!localStorageSaysAuthed()) setIsAuthenticated(false);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
    // Re-run on every client-side route change. The provider lives in the
    // root layout, so it never unmounts between pages — without this dep,
    // a user who logs in on /login and then clicks the NutriMind logo back
    // to / would still see "Sign In" because the effect never re-fires.
    // `cache: "no-store"` keeps each fetch authoritative.
  }, [pathname]);

  const signIn = () => {
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
  };

  const signOut = async () => {
    // Try to hit a backend logout endpoint if one exists; ignore failures
    // so the UI updates cleanly even if the backend doesn't expose one.
    try {
      await fetch("/api/logout", {
        method: "POST",
        credentials: "include",
      });
    } catch {
      // noop
    }
    clearLocalAuthHints();
    setIsAuthenticated(false);
    if (typeof window !== "undefined") {
      window.location.reload();
    }
  };

  return (
    <AuthContext.Provider
      value={{ isAuthenticated, isLoading, signIn, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
