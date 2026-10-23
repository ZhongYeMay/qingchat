# Chat maintenance

- For every user-visible release, update `src/releases.js` and the version in `package.json`. Keep the Settings → About → Changelog current and include a concise Chinese summary.
- Build with `npm run build` before publishing. Commit generated app.js, share.js and invite.js together with source; build scripts update content-based asset versions.
- Keep existing Supabase auth/session storage keys and table names stable unless a data migration is explicitly needed.
- Sharing must remain an explicit, revocable snapshot of selected messages. Do not expose live conversation tables or place private chat content in the public Git repository.
- Notification permissions must be requested only after a user's button click. Clearly state that realtime notifications require the page to remain open.

- All product copy must use formal, neutral, concise Chinese with consistent terminology. Avoid conversational prompts, slogans, and decorative emoji in default content. Preserve user-authored messages, posts, invitations, and customized text.
