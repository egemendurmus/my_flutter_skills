# Security review

- Search for embedded secrets, private keys, hardcoded SSH/VNC passwords, production database credentials and tokens. Never repeat discovered secret values in output.
- Recommend credential rotation when real credentials appear in committed history; removing a literal from the latest revision is insufficient.
- Store secrets in platform secure storage when suitable; do not treat SharedPreferences as a secure secret vault. Consider device provisioning and server-side authentication for shared industrial credentials.
- Validate untrusted file names and paths before interpolation into SSH shell commands; use strict allowlists and shell-safe construction. Guard archive extraction against path traversal.
- For SFTP uploads, verify file integrity and remote staging; design rollback across *all* selected directories, not just one, where operational safety requires atomicity.
- Validate DB query parameters; avoid string interpolation for user-controlled values. Restrict network privileges, TLS/SSH host verification and permissions.
- For VNC, confirm supported RFB versions and authentication types rather than assuming VNC Authentication; manage sockets, timeouts, reconnects and simultaneous sessions safely.
- Do not run live equipment commands or destructive migrations without authorization, backups and a test plan.
