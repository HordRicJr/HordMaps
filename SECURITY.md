
# Security Policy

## Supported Versions

Use this section to tell people about which versions of your project are
currently being supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 5.1.x   | :white_check_mark: |
| 5.0.x   | :x:                |
| 4.0.x   | :white_check_mark: |
| < 4.0   | :x:                |

---

## Reporting a Vulnerability

If you've found a potential vulnerability in **HordMaps**, thank you — we
want to fix it. Please follow the steps below to report it responsibly.

**Preferred reporting channels (choose one):**

1. **GitHub Security Advisories** — If available, open a private Security
   Advisory in this repository.
2. **Email (PGP optional):** [security@your-domain.example](mailto:security@your-domain.example) *(replace with a
   working address)*. If you prefer encrypted email, add our PGP key at
   `https://yourdomain.example/pgp` (replace with real link).

> ⚠️ Do **not** open public GitHub issues with exploit code or full
> proof‑of‑concepts. That puts users at risk. Use the channels above.

### What to include in your report

Please provide as much of the following as you can:

* A short, descriptive title for the issue.
* Affected version(s) (example: `v5.1.2`, `master` commit hash).
* A clear description of the vulnerability and the impact.
* Steps to reproduce (exact commands, URLs, payloads) or a minimal
  proof-of-concept (attach as text or encrypted file if sensitive).
* Any logs, screenshots, or stack traces that help reproduce the issue.
* Your contact information (GitHub handle and/or email) and whether you
  allow us to credit you publicly for the report.

### Response timeline

* **Acknowledgement:** We'll respond within **72 hours** to confirm
  receipt.
* **Initial triage & status update:** We will aim to provide a status
  update within **14 days**.
* **Fix & disclosure:** We'll work to provide a fix or mitigation and
  coordinate a responsible disclosure timeline. Critical/security‑impacting
  fixes may be coordinated with a CVE and timed disclosure.

If you do not receive a reply within the above timelines, please follow
up through the same channel.

### Severity & classification

We follow common industry severity guidance (informational, low, medium,
high, critical). During triage we will classify the report and prioritize
work accordingly.

### Coordinated disclosure

We request that reporters allow us reasonable time to investigate and
release a fix before publishing exploit details. If you plan to publish
findings, please notify us of your intended disclosure date so we can
coordinate.

### After a report is accepted

* If the report is confirmed and fixed, we will:

  * Credit the reporter in the changelog or security advisory (unless the
    reporter asks for anonymity).
  * Provide CVE assignment where appropriate.
  * Publish a short advisory describing the issue, affected versions, and
    mitigation steps.

---

## If you are a maintainer: configuring the repo

To make secure reporting easier:

* Enable **GitHub Security Advisories** in repository settings.
* Set a repository security contact email in Settings → Security & analysis.
* Add a PGP key or link if you accept encrypted reports.
* Add the following labels: `security`, `security-accepted`, and
  `hacktoberfest-accepted` (optional — see Hacktoberfest guidance below).

---

## Hacktoberfest checklist (optional, for better contributor experience)

If you want this repository to be friendly for Hacktoberfest contributors:

* Add the `hacktoberfest` topic to the repository.
* Create clear `good first issue` and `help wanted` issues with tags and
  detailed reproduction steps.
* Use the label `hacktoberfest-accepted` to mark PRs that count toward
  Hacktoberfest when merged.
* Consider adding a CONTRIBUTING.md with a short section on how to
  submit a secure bug fix or vulnerability fix (e.g., avoid publishing
  exploit details in public PRs).

---

## Legal & privacy notes

By sending a vulnerability report you agree to provide only information
necessary to reproduce and fix the issue. We will not use reports for any
purpose other than triage and remediation. If required, we may ask for a
non-disclosure agreement for sensitive cooperation.

---

If you'd like, replace placeholders (emails, PGP link) with your real
values and I'll finalize the file for you.
