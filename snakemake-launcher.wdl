version 1.0

workflow SnakemakeBatchLauncher {
  call RunSnakemakeBatch
}

task RunSnakemakeBatch {
  input {
    File snakefile
    File script
    File env_yaml
    String remote_prefix
    String docker_image
  }

  command <<<
    export GOOGLE_REGION=$(basename $(curl --silent -H "Metadata-Flavor: Google" metadata/computeMetadata/v1/instance/zone 2> /dev/null) | cut -d "-" -f1-2)
    export GOOGLE_PROJECT=$(gcloud config get-value project)
    export SERVICE_ACCOUNT_EMAIL=$(gcloud config get-value account)
    mkdir -p workspace &&
    cp ~{snakefile} workspace/Snakefile &&
    cp ~{script} workspace/check_file.py &&
    cp ~{env_yaml} workspace/snakemake-env.yaml &&
    cd workspace &&
    snakemake \
      --google-batch \
      --default-remote-prefix ~{remote_prefix} \
      --jobs 10 \
      --latency-wait 60 \
      --use-conda \
      --rerun-incomplete \
      --google-batch-region $GOOGLE_REGION \
      --google-batch-service-account-email $SERVICE_ACCOUNT_EMAIL \
      --google-batch-project $GOOGLE_PROJECT
  >>>

  runtime {
    docker: docker_image
    memory: "4G"
    cpu: 2
  }

  output {
    File log = "workspace/.snakemake/log/snakemake.log"
  }
}
