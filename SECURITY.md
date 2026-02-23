# Security policy

This repository builds and publishes a snap that repackages the `network-manager`
package from the official Ubuntu archives for Ubuntu Core systems.

Because this is a repackaging repository, security issues can come from two sources:

- The snap packaging and repository-specific integration (hooks, configuration,
  startup behavior, and patches carried in this repository).
- The upstream `network-manager` package and other archive-sourced components.

## Supported versions
When reporting security issues against this snap, only the latest published
revision is supported. Please reproduce on the newest revision available in your
channel before reporting.

Security fixes may be delivered as:

- Repository-specific fixes in this snap source tree.
- Rebuilds that pick up fixes from Ubuntu archive packages.

## What qualifies as a security issue

Any vulnerability that allows the snap to interfere outside of the intended 
restrictions qualifies as a security issue, including vulnerabilities that
allows an unprivileged user on the local system to escalate privileges or cause a 
denial of service etc due to the use of the contents of the snap on the system.

## Reporting a vulnerability

Please report vulnerabilities privately.

For issues specific to this repository/snap packaging, use GitHub private
vulnerability reporting for this project:

- https://github.com/canonical/network-manager-snap/security/advisories/new

See
[Privately reporting a security
vulnerability](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability)
for instructions.

For vulnerabilities in Ubuntu archive packages (including upstream
`network-manager` code), follow Ubuntu's security reporting process:

- https://ubuntu.com/security/vulnerability-reporting

The [Ubuntu Security disclosure and embargo
policy](https://ubuntu.com/security/disclosure-policy) contains more
information about what you can expect when you contact us, and what we
expect from you.
