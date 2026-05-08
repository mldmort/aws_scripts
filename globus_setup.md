# Globus on macOS for SFARI → Expanse transfers

A practical setup guide based on the path used to stage SPARK iWGS_v1.1 CRAMs
from SFARI (Flatiron) to SDSC Expanse Lustre for downstream mosdepth runs.

## 1. Install the CLI

`globus-cli` isn't in Homebrew, so use `pipx`:

```bash
brew install pipx
pipx install globus-cli
pipx ensurepath          # ensures ~/.local/bin/globus is on PATH
```

## 2. Authenticate

```bash
globus login            # opens a browser; sign in with your Globus account
globus whoami           # confirm
```

The auth flow stores tokens under `~/.globus/cli/storage.db`.

## 3. Identity linking (only if you'll use endpoints that map to a different account)

Globus lets one Globus account link to multiple identities (UCSD SSO, ACCESS-CI,
etc.). Some endpoints look at *which* linked identity is active in your
session to decide which Linux user to map you to. Two relevant cases here:

- **SFARI guest collection** (`98f73ff6-b423-11ec-bae0-cd8db799a66a`) — needs
  `sebatlab@globusid.org` on the source side.
- **SDSC HPC - Expanse Lustre** (`8735b734-00dc-4659-be0d-ff96beaff17b`) —
  needs an **ACCESS-CI** identity that maps to your `smmortazavi` Linux account
  on Expanse.

**Link a new identity to your Globus account** (one-time, browser-based):
1. Visit <https://app.globus.org/account/identities> while signed in to Globus.
2. Click **"Link to an existing account"** and pick the identity provider
   (UCSD SSO, ACCESS / CILogon, etc.).
3. Sign in with that identity. You'll return to a page showing both identities
   linked.

**Activate a linked identity in the current CLI session:**

```bash
globus session update <username>@<idp>     # e.g. milad1@access-ci.org
globus whoami --linked-identities -v       # see what's linked
globus session show                        # see what's active in this session
```

## 4. Add per-collection data_access consents

Some endpoints require an extra "data access" scope before listing/transferring.
The CLI prints the exact command when you hit the wall:

```bash
globus session consent 'urn:globus:auth:scope:transfer.api.globus.org:all[*https://auth.globus.org/scopes/<COLLECTION_UUID>/data_access]'
```

This was needed twice — once for the SFARI collection's parent GCS endpoint,
once for SDSC's Expanse Lustre.

## 5. Find endpoints

```bash
globus endpoint search 'expanse'                       # public name search
globus endpoint search --filter-scope my-endpoints     # endpoints you own
globus collection show <UUID>                          # guest/mapped collections
```

Endpoints used here:

| name | UUID | type | exposes |
|---|---|---|---|
| **SFARI Collections** | `98f73ff6-b423-11ec-bae0-cd8db799a66a` | GCS guest | `/SPARK/`, `/SSC_hg19/`, `/SSC_hg38/`, ... |
| **SDSC HPC - Expanse Lustre** | `8735b734-00dc-4659-be0d-ff96beaff17b` | GCS mapped | `/projects/ddp195/<user>/...`, `/scratch/...` |

**Path note:** the Lustre endpoint exposes paths *without* the
`/expanse/lustre/` prefix. So the Linux path
`/expanse/lustre/projects/ddp195/smmortazavi/x` is
`/projects/ddp195/smmortazavi/x` to Globus.

## 6. Browse

```bash
globus ls 98f73ff6-b423-11ec-bae0-cd8db799a66a:/SPARK/pub/iWGS_v1.1/
globus ls -l <UUID>:/path/        # long format with sizes / timestamps
```

## 7. Transfer

**Single file:**

```bash
globus transfer \
  98f73ff6-...:/SPARK/pub/iWGS_v1.1/cram/0/SP0001710.cram \
  8735b734-...:/projects/ddp195/smmortazavi/staging/SP0001710.cram \
  --label "single-test" --preserve-mtime
```

**Many files via batch input** (what `globus_transfer/submit_transfer.sh` does
— much faster than separate tasks since Globus parallelizes across files in a
single task):

```bash
# stdin: one "<src> <dst>" per line
globus transfer 98f73ff6-... 8735b734-... \
  --label "spark-batch" --preserve-mtime --batch -
```

## 8. Monitor

```bash
globus task list                          # recent tasks
globus task show <TASK_ID>                # detail (status, bytes, faults)
globus task wait <TASK_ID> --timeout 1800 # block until done (or timeout)
globus task event-list <TASK_ID>          # per-event log; useful for failures
globus task cancel <TASK_ID>              # stop a running/retrying task
```

For programmatic monitoring, parse `globus task show`'s `Status:` and
`Bytes Transferred:` lines.

## 9. What "good throughput" looks like

Measured on this workload (SFARI → SDSC Expanse Lustre, GCS-to-GCS):

| transfer shape | rate | example |
|---|---|---|
| Single 15 GB CRAM | ~85 MB/s | one file = no inter-file parallelism |
| 100 CRAMs as one batch task (1.9 TB) | **~1.7 GB/s aggregate** | Globus parallelizes across files |
| 50 TB extrapolation at 1.7 GB/s | ~9 hours | the realistic full-batch rate |

## 10. Common errors and fixes

| symptom | cause | fix |
|---|---|---|
| `MissingLoginError: Missing 'manage_collections' consent` | endpoint metadata needs an extra scope | run the `globus login --gcs <id>` command the CLI prints |
| `requires you to grant consent for the Globus CLI to access it` | per-collection `data_access` scope missing | run the `globus session consent` command the CLI prints |
| `PERMISSION_DENIED ... STOR ... Permission denied` | identity mapping wrong on dest endpoint | `globus session update <correct-identity>`; ensure target dir is writable by the mapped Linux user |
| `UNKNOWN_SCOPE_ERROR` on `data_access` | the collection doesn't have HTTPS-bearer access registered | Bearer-token HTTPS GETs unavailable; use Globus Transfer Protocol instead |
| `EndpointDeleted` on local endpoint | unused GCP endpoint garbage-collected | relaunch Globus Connect Personal to re-register, or use a different endpoint |
| `[E::hts_open_format] ... Exec format error` on the CRAM | source file isn't a valid CRAM (wrong magic bytes), not a transfer issue | re-fetch with `--verify-checksum`; if the bytes still match the source, the file at SFARI is bad — flag to SFARI |
