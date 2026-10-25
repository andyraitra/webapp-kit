# Security policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately through
[GitHub private vulnerability reporting](https://github.com/andyraitra/webapp-kit/security/advisories/new).

Include the version, the exact command and a description of the impact. You should
get a first answer within 7 days. Once a fix is released, the advisory is published
with credit to the reporter unless you prefer to stay anonymous.

## Scope

In scope: anything that lets a name, URL, icon or downloaded content make
`webapp-install` / `webapp-remove` execute commands, write or delete files outside
their data directories, or produce a desktop entry that runs something other than
the browser with the requested URL.

Out of scope: the behaviour of the websites themselves or of the browser.

## Known limitation

Icon links found on a public page are not fetched when they point at `localhost`,
private or link-local addresses (in any numeric spelling), including through
redirects. The check is based on the host name as written: a public DNS name that
resolves to a private address (e.g. DNS rebinding) is not detected. The impact is
limited to a blind GET request without cookies whose response is only kept if it is
a valid image.
