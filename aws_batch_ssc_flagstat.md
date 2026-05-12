# SSC samtools flagstat via AWS Batch

Run `samtools flagstat` on the 9039 SSC WGS CRAMs in `s3://sscwgs-hg38/` and
produce a master TSV matching the column layout of the colleague's 2023 SPARK
iWGS_v1.1 master table.

## Design choices

- **Stream CRAMs from S3** via htslib's S3 plugin — no local download, no
  large root EBS needed. Runs on the existing `genomics-spot-v2` compute env
  with its default 30 GB EBS.
- **EC2 Spot, not Fargate** — Spot is ~5x cheaper per vCPU-hr and we don't
  need Fargate's per-task ephemeralStorage now that nothing hits the disk.
- **Cross-account read** of `s3://sscwgs-hg38/` requires the request to
  originate in us-east-1 (SFARI's bucket policy has a region/IP condition).
  Batch tasks naturally satisfy this since the queue is in us-east-1.

## Prerequisites (already set up)

| | |
|---|---|
| ECR image | `640838474376.dkr.ecr.us-east-1.amazonaws.com/flagstat-ssc:v1` |
| Batch job def | `flagstat-ssc:1` (EC2, 4 vCPU, 4 GB) |
| Compute env / queue | `genomics-spot-v2` / `genomics-queue` |
| Samples manifest | `s3://sebat-genomics-work/coverage_ssc/_inputs/samples.csv` (reused from the mosdepth run; 9039 rows) |
| Output prefix | `s3://sebat-genomics-work/flagstat_ssc/results/` |
| sfari keys | Read from your local `~/.aws/credentials` profile `sfari` at submit time; passed to the container via `--container-overrides` |

## Files in `flagstat_ssc/`

| file | role |
|---|---|
| `Dockerfile` | Ubuntu 22.04 + samtools (apt 1.13) + awscli2; sets `HTS_PATH=/usr/lib/x86_64-linux-gnu/htslib` so the S3 plugin is discoverable |
| `run_flagstat.sh` | per-sample worker: streams `samtools flagstat -O json` from S3 and parses to a 21-col TSV |
| `build_and_push.sh` | build + push to ECR (run from the orchestrator EC2) |
| `job-definition.json` | Batch job def — EC2, 4 vCPU / 4 GB, env vars |
| `submit_array.sh` | submit wrapper; reads `SFARI_ACCESS_KEY`/`SFARI_SECRET_KEY` from env, passes via container overrides |
| `0_run.sh` | 1-sample smoke test |
| `1_run.sh` | 5-sample test array |
| `2_run.sh` | full 9039-sample run |
| `aggregate.sh` | pull all per-sample TSVs from S3 and concat into `SSC.cram_stats.tsv` (21 cols + header) |

## Workflow

### One-time setup (already done)

```bash
# Create ECR repo (from a host with ecr:CreateRepository, e.g. your laptop)
aws --profile default --region us-east-1 ecr create-repository \
  --repository-name flagstat-ssc

# Build + push image (from the orchestrator EC2; needs Docker + ECR push)
ssh -A ubuntu@<orchestrator-ip>
cd ~/aws_scripts && git pull
cd flagstat_ssc && ./build_and_push.sh

# Register the job def (from your laptop)
aws --profile default --region us-east-1 batch register-job-definition \
  --cli-input-json file://job-definition.json
```

### Running a batch

All run wrappers read `SFARI_ACCESS_KEY` / `SFARI_SECRET_KEY` from env. Easiest:

```bash
export SFARI_ACCESS_KEY=$(aws --profile sfari configure get aws_access_key_id)
export SFARI_SECRET_KEY=$(aws --profile sfari configure get aws_secret_access_key)

./0_run.sh        # 1-sample smoke (~7 min)
./1_run.sh        # 5-sample test (~12 min)
./2_run.sh        # full 9039 (~10-12 hr at ~64 concurrent)
```

### Checking progress

```bash
# array status summary
aws --profile default --region us-east-1 batch describe-jobs \
  --jobs <job-id> \
  --query 'jobs[0].arrayProperties.statusSummary' --output json

# count completed outputs in S3
aws --profile default s3 ls s3://sebat-genomics-work/flagstat_ssc/results/ \
  | grep -c '\.tsv$'
```

### Aggregating

After the full run completes:

```bash
./aggregate.sh
# writes ./SSC.cram_stats.tsv
```

## Output format (21 columns)

Matches the colleague's `SPARK.iWGS_v1.1.mastertable.cram_stats.2023_03.tsv`:

```
spid  total  primary  secondary  supplementary  duplicates  primary_duplicates
mapped  mapped_pct  primary_mapped  primary_mapped_pct  paired  read1  read2
properly_paired  properly_paired_pct  paired_and_mate_mapped  singletons
singletons_pct  mate_mapped_diff_chr  mate_mapped_diff_chr_pct
```

Note: `mate_mapped_diff_chr_pct` is misleadingly named upstream — it's the
**mapQ>=5 count** of "with mate mapped to a different chr", not a percentage.
The worker preserves that field's actual contents to match the source schema.

## Cost + timing (measured)

| metric | value |
|---|---|
| Per-task wall (running) | 5-10 min |
| Per-task cost (EC2 Spot, 4 vCPU) | ~$0.006 |
| Full 9039 cost | **~$60** |
| Full wall-clock at 64 concurrent | **~10-12 hours** |
| Output volume | ~10 MB (9039 × ~1 KB JSON + ~180 B TSV each) |

(Compare to Fargate's ~$400 for the same workload — Spot is much cheaper
because we don't need per-task ephemeralStorage.)

## Common issues

| symptom | cause | fix |
|---|---|---|
| `Protocol not supported` opening `s3://...` | samtools can't find htslib S3 plugin | ensure `HTS_PATH=/usr/lib/x86_64-linux-gnu/htslib` is set in env (baked into the image already) |
| 403 from `s3://sscwgs-hg38/...` | request not originating in us-east-1 | Batch tasks are us-east-1; only a problem if you try to test from a non-us-east-1 host |
| Job stays `RUNNABLE` forever | no Spot capacity at the instance type Batch chose | normally clears in 1-3 min; if longer, check `genomics-spot-v2` status |
| `ERROR: missing INDEX` | non-array submit didn't pass `$1` to the worker | `submit_array.sh` handles this: passes `command: ["<start-index>"]` for size=1 |

## What's next

- Sync `s3://sebat-genomics-work/flagstat_ssc/results/` to SDSC Ceph
  (same two-leg pattern as `coverage_ssc/sync_to_sdsc.sh` — pulls to a Lustre
  staging dir on Expanse, pushes to `s3://sebat/flagstat_ssc/`).
- Run the aggregator and join the result into your downstream analysis.
