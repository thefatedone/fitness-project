import { NextResponse, type NextRequest } from "next/server";

/**
 * Server-side auth probe used by the client AuthContext. Reads the request's
 * cookie header (where HttpOnly session cookies ARE visible, unlike
 * `document.cookie` in the browser) and reports whether the request
 * appears to carry an authenticated session.
 *
 * This endpoint deliberately does not call the backend — the FastAPI
 * service owns the real session validation; this is just a UI hint so
 * the landing page can show "Sign Out" instead of "Sign In" after the
 * user comes back from /dashboard/profile. The actual auth gate happens
 * on the backend side, so any cookie spoofing that slipped past the
 * browser would still be rejected by the real protected routes.
 */

const SESSION_COOKIE_CANDIDATES = [
  "session",
  "auth_token",
  "token",
  "nutrimind_session",
  "connect.sid",
  "PHPSESSID",
  "JSESSIONID",
  "sb-access-token",
  "sb-refresh-token",
];

function hasSessionCookie(cookieHeader: string): boolean {
  if (!cookieHeader) return false;
  const cookies = cookieHeader.split("; ");
  return SESSION_COOKIE_CANDIDATES.some((name) =>
    cookies.some((c) => c.startsWith(`${name}=`)),
  );
}

export function GET(req: NextRequest) {
  const cookieHeader = req.headers.get("cookie") ?? "";
  return NextResponse.json(
    { authenticated: hasSessionCookie(cookieHeader) },
    { status: 200 },
  );
}
