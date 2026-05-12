# samtools flagstat image for SSC WGS — streams CRAMs directly from S3
# (no local download, no large root volume needed), so it runs cleanly on
# the existing genomics-spot-v2 compute env with its default 30 GB EBS.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip python3 \
        samtools && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2 (apt's awscli is too old)
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Ubuntu's libhts plugins live at a different path than samtools' compiled-in
# default. Set HTS_PATH so the S3 plugin is discoverable at runtime.
ENV HTS_PATH=/usr/lib/x86_64-linux-gnu/htslib

COPY run_flagstat.sh /usr/local/bin/run_flagstat.sh
RUN chmod +x /usr/local/bin/run_flagstat.sh

ENTRYPOINT ["/usr/local/bin/run_flagstat.sh"]
