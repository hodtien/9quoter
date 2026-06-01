# Basic Auth 9router Connection Design

## Goal

Allow 9Quoter to connect to a remote 9router such as `https://9router.karlorc.us` when the server is protected by HTTP Basic Auth in addition to the normal 9router password login.

## Selected direction

Use first-class Basic Auth configuration in the app instead of embedding credentials in the server URL.

This keeps the server URL clean, avoids exposing credentials in visible text fields, and lets the app store both the 9router login password and Basic Auth credentials in Keychain-backed storage.

## Behavior

- Users enter the 9router server URL as usual.
- Users enter the normal 9router password as usual.
- Users can optionally expand or fill a Basic Auth section with username and password.
- If Basic Auth credentials are present, every request to the configured 9router server includes an `Authorization: Basic ...` header.
- The 9router password still authenticates through `/api/auth/login` and produces the existing auth token cookie.
- Clearing or leaving Basic Auth fields empty disables Basic Auth headers.
- Logging out clears the 9router token and stored login password; Basic Auth credentials remain as connection settings unless the user explicitly clears them in Settings.

## UI

### Login view

The initial connection form should include an optional Basic Auth area below the 9router password field. It can be visually secondary because most local installations do not need it.

Fields:

- Server URL
- 9router password
- Basic Auth username
- Basic Auth password

The Basic Auth fields should be clearly labeled as server-level protection, separate from the 9router password.

### Settings view

Settings should include the same Basic Auth username and password controls so users can update remote access without re-entering the 9router password.

The save/sign-in behavior should remain simple:

- Save persists URL and Basic Auth settings.
- Sign in additionally sends the 9router password to `/api/auth/login`.

## Storage

- Store Basic Auth username and password in Keychain, not UserDefaults.
- Store only non-sensitive settings such as base URL and refresh interval in UserDefaults.
- Use distinct Keychain keys for Basic Auth username and Basic Auth password so clearing either field is explicit.

## Networking

Centralize Basic Auth header application inside `RouterService` so each request path behaves consistently.

Requests that need the Basic Auth header include:

- `/api/auth/login`
- provider/client API requests
- provider quota API requests
- account update requests
- usage stats/chart requests
- usage stream requests

Existing cookie-based 9router auth remains unchanged:

- `Cookie: locale=en; auth_token=...` stays on authenticated API requests.
- `Authorization: Basic ...` is added only when Basic Auth credentials exist.

## Error handling

- If Basic Auth is missing or wrong, the remote server will likely return `401` before 9router handles the request.
- The app should surface the existing login/network error message path rather than introducing a second auth state.
- If the response is `401` during login and Basic Auth fields are configured, the message should guide the user to check either Basic Auth or the 9router password.

## Security

- Never store Basic Auth credentials in the URL.
- Never print Basic Auth credentials or encoded headers.
- Never persist Basic Auth credentials in UserDefaults.
- Prefer HTTPS for remote 9router URLs.

## Testing

- Verify a login request includes Basic Auth when credentials are configured.
- Verify a login request omits Basic Auth when credentials are empty.
- Verify authenticated API requests include both the auth token cookie and Basic Auth header when configured.
- Verify Settings persistence loads Basic Auth credentials from Keychain.
- Verify clearing Basic Auth fields stops sending the `Authorization` header.
