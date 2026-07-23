/// Client-side password-length gate for the Phase 4b account-upgrade create
/// flow (`CreateAccountScreen`), checked before ever calling
/// `AccountService.startCreateAccount` so a too-short password never costs a
/// network round trip. Deliberately a single named constant rather than a
/// literal scattered across the UI: default 6, but this must match this
/// project's actual Supabase Auth password-policy minimum, which only the
/// human can confirm (see this feature's build report) - flagged here, not
/// guessed at. Also reused, as the best available local approximation, to
/// word a server-side `AccountError.weakPassword` rejection, since the
/// client has no visibility into the server's exact policy otherwise.
const int kMinPasswordLength = 6;
