# mosdepth + awscli image for the coverage_spark_ssc Batch run.
# Built off micromamba so we get clean, pinned versions of both tools.
FROM mambaorg/micromamba:1.5.10

USER root

ARG MOSDEPTH_VERSION=0.3.6
RUN micromamba install -y -n base -c bioconda -c conda-forge \
        mosdepth=${MOSDEPTH_VERSION} \
        awscli \
        ca-certificates && \
    micromamba clean -ay

ENV PATH="/opt/conda/bin:${PATH}"

COPY run_mosdepth.sh /usr/local/bin/run_mosdepth.sh
RUN chmod +x /usr/local/bin/run_mosdepth.sh

ENTRYPOINT ["/usr/local/bin/run_mosdepth.sh"]
