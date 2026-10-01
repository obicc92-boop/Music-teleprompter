# Releasing the Mac app

Until the app is signed by Apple, macOS tells whoever downloads it that it is
damaged or comes from an unidentified developer. This is the one-off setup
that removes that, and the routine for cutting a release afterwards.

Everything here can be done from Windows — no Mac needed. The commands are
for Git Bash.

---

## One-off setup

### 1. Join the Apple Developer Program

<https://developer.apple.com/programs/> — $99 a year. Enrol as an individual
unless you already have a company; it can take a day or two, and Apple may
ask for ID.

Afterwards, note your **Team ID** (a 10-character code) from
<https://developer.apple.com/account> → Membership details.

### 2. Create a Developer ID certificate

This is the certificate that says builds come from you. It is **not** the
same as a "Development" or "Apple Distribution" certificate — only
*Developer ID Application* works for apps handed out as a download, and only
the account holder can create one.

Make a key and a signing request:

```bash
openssl genrsa -out developerID.key 2048
openssl req -new -key developerID.key -out developerID.csr \
  -subj "/emailAddress=YOU@example.com/CN=YOUR NAME/C=DE"
```

Then at <https://developer.apple.com/account/resources/certificates/list>:
**+** → **Developer ID Application** → upload `developerID.csr` → download
`developerID_application.cer`.

Also download Apple's intermediate certificate, so the signature carries its
whole chain: <https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer>

Bundle the lot into a `.p12`, choosing a password when asked:

```bash
openssl x509 -inform DER -in developerID_application.cer -out developerID.pem
openssl x509 -inform DER -in DeveloperIDG2CA.cer -out DeveloperIDG2CA.pem
openssl pkcs12 -export -legacy -out certificate.p12 \
  -inkey developerID.key -in developerID.pem -certfile DeveloperIDG2CA.pem \
  -name "Developer ID Application"
```

`-legacy` matters: without it OpenSSL 3 writes a file macOS refuses to
import ("MAC verification failed").

**Keep `certificate.p12`, `developerID.key` and the password somewhere safe
— a password manager, not this repo.** The certificate lasts five years and
replacing it means going through Apple again.

### 3. Create an app-specific password

Notarization signs in as you, and your real password won't do. At
<https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords,
generate one called `notarization` and copy it.

### 4. Put the five secrets in GitHub

Turn the certificate into one line of text (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12")) | Set-Clipboard
```

Then at **Settings → Secrets and variables → Actions → New repository
secret**, add:

| Secret | What goes in it |
|---|---|
| `MACOS_CERTIFICATE` | the base64 text just copied |
| `MACOS_CERTIFICATE_PASSWORD` | the password used in the `openssl pkcs12` command |
| `APPLE_ID` | the Apple ID email the membership is under |
| `APPLE_APP_PASSWORD` | the app-specific password from step 3 |
| `APPLE_TEAM_ID` | the 10-character Team ID from step 1 |

The build signs and notarizes as soon as all of them exist, and quietly
produces an unsigned DMG while any are missing — so nothing breaks in the
meantime.

---

## Cutting a release

1. Set the version in `pubspec.yaml` (for example `version: 1.1.0+2`).
2. Commit it.
3. Tag and push:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow builds, signs, notarizes and staples the app and the DMG, then
publishes a **Releases** page with a download link that works for anyone,
with no GitHub account. Pushes to `main` without a tag still build a DMG,
but leave it as a run artifact rather than publishing it.

Notarization adds roughly five minutes per build: Apple is asked twice, once
for the app and once for the DMG. Both get a stapled ticket, so the app opens
even on a stage with no wifi.

---

## When it goes wrong

The build prints Apple's own log on a rejection — read that first. The usual
causes:

| What Apple says | What it means |
|---|---|
| *The binary is not signed with a valid Developer ID certificate* | the `.p12` holds the wrong kind of certificate — redo step 2 and pick **Developer ID Application** |
| *The signature does not include a secure timestamp* | signed while Apple's timestamp server was unreachable; re-run the build |
| *The executable does not have the hardened runtime enabled* | a binary was signed without `--options runtime`; check the new file in `Contents/Frameworks` |
| `security: MAC verification failed` when importing | the `.p12` was exported without `-legacy` |
| *No 'Developer ID Application' certificate in MACOS_CERTIFICATE* | the base64 is truncated, or the `.p12` has no private key in it |

To check a finished DMG by hand on a Mac:

```bash
spctl --assess --type open --context context:primary-signature -v MusicTeleprompter-1.0.0.dmg
xcrun stapler validate MusicTeleprompter-1.0.0.dmg
```

---

## Still unsigned

Windows builds are not signed yet, so they raise a SmartScreen warning.
Publishing through the Microsoft Store is the cheap way out of that: they
sign it for you, where a Windows code-signing certificate costs a few hundred
a year and needs a hardware token.
