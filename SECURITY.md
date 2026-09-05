# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a suspected security or safety problem. Use the repository's private GitHub security-advisory flow from the **Security** tab and include a concise description, reproduction steps, affected version, and potential impact.

If private advisories are unavailable, open an issue without sensitive details and request a private follow-up.

Reports are reviewed privately. FENR includes authenticated, guarded vehicle controls; vulnerabilities involving credentials, Bluetooth pairing, telemetry exposure or vehicle writes are treated as high priority.

Do not include real motorcycle identifiers, pairing material, tokens, raw captures or location histories in public issues, patches or test fixtures. Use synthetic data. If a credential was committed, revoke or rotate it before coordinating any history cleanup; deleting the latest file alone does not remove it from earlier commits.

## Repository checks

CI scans reachable Git history with Gitleaks. Run the same check locally with:

```sh
brew install gitleaks
gitleaks git --redact --log-opts=--all .
```

Also inspect the proposed files and history for motorcycle identifiers, location
data, signing material and private captures. A credential scanner does not
reliably identify that data. Keep local signing overrides, credentials and
generated diagnostic output in the ignored locations declared by `.gitignore`.
