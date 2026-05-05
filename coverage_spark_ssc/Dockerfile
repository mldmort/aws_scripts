# mosdepth + awscli image for the coverage_spark_ssc Batch run.
# Uses precompiled binaries (no conda solver) so the build fits in <2 GB RAM
# on the t3.small orchestrator and produces a small, fast image.
FROM ubuntu:22.04

ARG MOSDEPTH_VERSION=0.3.6

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2 from the official installer
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# mosdepth: precompiled, statically linked binary (bundles htslib)
RUN curl -fsSL "https://github.com/brentp/mosdepth/releases/download/v${MOSDEPTH_VERSION}/mosdepth" \
        -o /usr/local/bin/mosdepth && \
    chmod +x /usr/local/bin/mosdepth

COPY run_mosdepth.sh /usr/local/bin/run_mosdepth.sh
RUN chmod +x /usr/local/bin/run_mosdepth.sh

ENTRYPOINT ["/usr/local/bin/run_mosdepth.sh"]
