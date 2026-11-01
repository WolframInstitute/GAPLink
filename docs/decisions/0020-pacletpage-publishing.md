# PacletPage publishing

Status: accepted

This replaces the custom page publishing in decisions 0012 and 0016.

Use PublishPacletPage for the resource and documentation site. Release jobs restore
the documentation and archive verified by CI and publish with Build -> False.
PacletPage checks the restored sources and archive before connecting to the cloud.

Keep four platform downloads at their existing URLs. A small adapter uploads these
archives and their resource descriptions. The main resource points to a description
that selects the platform using the installing kernel's $SystemID. The generated
page and copied examples therefore install the matching bundled GAP runtime.
Unsupported systems return a Failure. No publishing library internals are patched.

Only a matching release tag on main may publish. Local verification does not connect
to the cloud. Preserve PacletPage's version and commit metadata when attaching the
platform description, and check public downloads after publishing.
