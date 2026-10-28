"""Parse an "Update an app" issue (.github/ISSUE_TEMPLATE/update-app.yml).

Reads the issue body from $ISSUE_BODY and the APPS list from $APPS (JSON), and
prints `key=value` lines for $GITHUB_OUTPUT: app, ref, submodules, s3. The body
is untrusted, so the app must be an APPS key and the ref a plain git ref name;
anything else exits 1 with the reason on stderr. s3 is "own", "other" or empty.
"""
import json
import os
import re
import sys

# Issue-form headings, as GitHub renders them into the body.
APP, VERSION = "App", "Version"
S3 = "Does it change what the app needs on S3?"
S3_CHOICES = {
    "It starts keeping its own files on S3": "own",
    "It needs other S3 data (describe below)": "other",
}
NO_RESPONSE = "_No response_"
# A branch, tag or sha: no spaces, no leading '-', no '..'.
REF = re.compile(r"^(?!-)(?!.*\.\.)[A-Za-z0-9._/-]{1,100}$")


def sections(body):
    """{heading: text} for each `### heading` block of an issue-form body."""
    out, heading, lines = {}, None, []
    for line in body.replace("\r\n", "\n").split("\n"):
        if line.startswith("### "):
            if heading is not None:
                out[heading] = "\n".join(lines).strip()
            heading, lines = line[4:].strip(), []
        else:
            lines.append(line)
    if heading is not None:
        out[heading] = "\n".join(lines).strip()
    return {k: ("" if v == NO_RESPONSE else v) for k, v in out.items()}


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def main():
    form = sections(os.environ.get("ISSUE_BODY", ""))
    apps = {a["key"]: a for a in json.loads(os.environ["APPS"])}
    app = form.get(APP, "")
    if app not in apps:
        fail(f"Unknown app {app!r}; expected one of: {', '.join(sorted(apps))}.")
    submodules = apps[app].get("submodules", "").split()
    if not submodules:
        fail(f"{app} isn't built from a submodule, so it can't be updated this way.")
    ref = form.get(VERSION, "")
    if ref and not REF.match(ref):
        fail(f"{ref!r} isn't a branch, tag or commit name.")
    print(f"app={app}")
    print(f"ref={ref}")
    print(f"submodules={' '.join(submodules)}")
    print(f"s3={S3_CHOICES.get(form.get(S3, ''), '')}")


if __name__ == "__main__":
    main()
