# AWS on macOS for Sebat lab + SFARI workflows

A practical setup guide based on the path used to wire up AWS access for the
Sebat lab account (S3, EC2, ECR, Batch) and SDSC Ceph (S3-compatible) at the
same time. Companion of `globus_setup.md`.

## 1. Install the AWS CLI

```bash
brew install awscli           # gets AWS CLI v2
aws --version
```

The Homebrew formula builds Python 3 + dependencies from source on older
macOS and can take several minutes — fine to leave running.

## 2. Profiles you'll have

Three profiles get used here, two AWS and one S3-compatible:

| profile | account / endpoint | role | purpose |
|---|---|---|---|
| `default` | `640838474376` (AWS) | IAM user `smmortazavi` | Sebat lab account: `sebat-genomics-work` S3, EC2 (orchestrator), ECR, Batch |
| `sfari` | `442630415362` (AWS) | IAM user `j3guevara@health.ucsd.edu` | List-only access to SFARI's `s3://sparkgenomics/`, `s3://sscwgs-hg38/` |
| `sebat` | `https://sebat.s3.sdsc.edu` (SDSC Ceph) | Ceph access key | Final destination bucket for results |

## 3. Set up `~/.aws/`

```bash
mkdir -p ~/.aws && chmod 700 ~/.aws
```

Drop in `~/.aws/credentials` (mode `600`):

```ini
[default]
aws_access_key_id     = <AKIA...>
aws_secret_access_key = <secret>

[sebat]
aws_access_key_id     = <ceph-key>
aws_secret_access_key = <ceph-secret>

[sfari]
aws_access_key_id     = <AKIA...>
aws_secret_access_key = <secret>
```

And `~/.aws/config` (mode `600`):

```ini
[default]
region = us-east-1
output = json

[profile sebat]
region = us-east-1
output = json
endpoint_url = https://sebat.s3.sdsc.edu
# SDSC Ceph RGW doesn't support botocore's newer flexible-checksum trailers
# (rejects requests with chunked encoding / no Content-Length). Disable them.
request_checksum_calculation = when_required
response_checksum_validation = when_required
```

The `sfari` profile is intentionally listed in `credentials` only; it inherits
the `default`-profile region. If you need to pin region or output for it, add
a `[profile sfari]` block to `config`.

## 4. Verify

```bash
aws --profile default sts get-caller-identity
aws --profile sfari   sts get-caller-identity
aws --profile sebat   s3 ls                    # Ceph endpoint
```

Each should print the IAM user ARN (or list buckets, for Ceph).

## 5. macOS quarantine when copying credential files

If you copied `~/.aws/config` and `~/.aws/credentials` from another Mac via
AirDrop, USB, or iCloud, macOS may add `com.apple.quarantine` extended
attributes. They don't change file content but can confuse tooling.

```bash
xattr ~/.aws/config ~/.aws/credentials
xattr -c ~/.aws/config ~/.aws/credentials   # strip xattrs if present
```

## 6. S3 commands by profile

```bash
# default profile (Sebat lab S3)
aws --profile default s3 ls
aws --profile default s3 ls s3://sebat-genomics-work/

# sfari profile (SFARI's AWS account — read-only by policy)
aws --profile sfari s3 ls s3://sparkgenomics/iWGS_v1.1/cram/

# sebat profile (SDSC Ceph)
aws --profile sebat s3 ls s3://sebat/
aws --profile sebat s3 cp file.txt s3://sebat/path/
```

## 7. EC2 management (orchestrator)

The lab keeps a `nextflow-orchestrator` EC2 (`i-072c23a921490581d`, t3.small,
us-east-1) for submitting Batch jobs and building Docker images. It's stopped
by default to save cost; start it when you need it.

```bash
# start
aws --profile default --region us-east-1 ec2 start-instances \
  --instance-ids i-072c23a921490581d

# wait until running
aws --profile default --region us-east-1 ec2 wait instance-running \
  --instance-ids i-072c23a921490581d

# get the (new) public IP — it changes each restart (no Elastic IP attached)
aws --profile default --region us-east-1 ec2 describe-instances \
  --instance-ids i-072c23a921490581d \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

# stop
aws --profile default --region us-east-1 ec2 stop-instances \
  --instance-ids i-072c23a921490581d
```

EBS storage continues to bill while stopped (~$0.80/month for the 8 GB root
volume); compute hours stop. The user's `~/.ssh/authorized_keys` survives a
stop/start.

## 8. SSHing into the orchestrator

The instance was launched with a `j3guevara-local` key pair, so by default
only j3guevara can ssh in. To add your own key:

1. **Have a colleague who can already log in** append your public key to
   `/home/ubuntu/.ssh/authorized_keys`. Self-service alternatives
   (Session Manager, EC2 Instance Connect) are blocked by the lab's IAM.
2. After that you SSH in with your usual key:

   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<public-ip>
   ```

3. For git operations from the orchestrator (e.g., `git clone` from a private
   GitHub repo), use **SSH agent forwarding** so the orchestrator can borrow
   your local SSH key for GitHub auth:

   ```bash
   ssh-add ~/.ssh/id_rsa
   ssh -A -i ~/.ssh/id_rsa ubuntu@<public-ip>
   ```

## 9. Fixing the orchestrator's broken AWS CLI

The orchestrator's pre-installed `awscli` (`/usr/bin/aws`) has a botocore
mismatch (`KeyError: 'opsworkscm'`). Replace with v2:

```bash
sudo apt-get update && sudo apt-get install -y unzip
cd /tmp
curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q -o awscliv2.zip
sudo ./aws/install --update
which aws         # should now be /usr/local/bin/aws
aws --version     # 2.x
```

Once on the orchestrator, the AWS CLI authenticates automatically via the
**`GenomicsInstanceRole`** EC2 instance profile — no `~/.aws/` setup needed
on the box. Different role than your local `default` user; permissions
differ (e.g., the role can pull from ECR but doesn't have
`ecr:DescribeRepositories`).

## 10. ECR (build + push from the orchestrator)

The orchestrator can `docker build` and `docker push` to ECR. Repo creation
must be done from a host that has `ecr:CreateRepository` (the orchestrator's
role doesn't), so create the repo from your laptop first, then build/push from
the orchestrator.

```bash
# from your laptop (smmortazavi has CreateRepository)
aws --profile default --region us-east-1 ecr create-repository \
  --repository-name <repo-name>

# on the orchestrator
aws --region us-east-1 ecr get-login-password \
  | docker login --username AWS --password-stdin \
      <account>.dkr.ecr.us-east-1.amazonaws.com
docker build -t <account>.dkr.ecr.us-east-1.amazonaws.com/<repo>:<tag> .
docker push   <account>.dkr.ecr.us-east-1.amazonaws.com/<repo>:<tag>
```

Build-image gotchas hit during this project:

- The orchestrator only has plain `docker build`, **no `docker buildx`**. Skip
  buildx — it's already linux/amd64 so no cross-arch needed.
- The `t3.small` orchestrator has 2 GB RAM. The conda/micromamba solver for
  `mosdepth + awscli` OOM-kills. Use precompiled binaries in the Dockerfile
  (mosdepth from GitHub releases, awscli v2 from Amazon's installer) instead
  of conda solving — produces a smaller, faster-to-build image.

## 11. AWS Batch (lab-shared)

Existing setup:

| | |
|---|---|
| Compute env | `genomics-spot-v2` (Spot EC2, max 256 vCPUs) |
| Job queue | `genomics-queue`, `genomics-fargate-queue` |
| S3 work dir | `s3://sebat-genomics-work/nextflow/` |

```bash
# register a job definition (JSON described in the Batch console docs)
aws --profile default --region us-east-1 batch register-job-definition \
  --cli-input-json file://job-definition.json

# array submit (size > 1 needs --array-properties)
aws --profile default --region us-east-1 batch submit-job \
  --job-name <name> --job-queue genomics-queue \
  --job-definition <name> \
  --array-properties size=N \
  --container-overrides '{"environment":[{"name":"FOO","value":"bar"}]}'

# monitor
aws --profile default --region us-east-1 batch list-jobs --job-queue genomics-queue
```

CloudWatch holds per-task stdout/stderr at the log group named in the job
definition (typically `/aws/batch/job`).

## 12. Common errors and fixes

| symptom | cause | fix |
|---|---|---|
| `command not found: aws` after install | Homebrew bin not on PATH | `eval "$(/opt/homebrew/bin/brew shellenv)"` |
| `AccessDeniedException` calling DescribeInstances | IAM user lacks region's EC2 read | use a different profile; or have admin grant `ec2:Describe*` |
| 403 Forbidden on `s3 cp` while `s3 ls` works | profile has `ListBucket` but not `GetObject` (cross-account or scoped policy) | request `GetObject` perm; or use the data through a different path (e.g., Globus) |
| `KeyError: 'opsworkscm'` on the orchestrator's `aws` | botocore/awscli version skew on the prebuilt VM | reinstall AWS CLI v2 from Amazon's installer (see §9) |
| ECR push fails with `unknown command: docker buildx` | orchestrator lacks the buildx plugin | use plain `docker build` + `docker push` |
| Build container OOM-killed at conda solve | t3.small has only 2 GB RAM | switch from conda solving to precompiled binaries in Dockerfile |
