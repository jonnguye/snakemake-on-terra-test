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
    METADATA="http://metadata.google.internal/computeMetadata/v1"
    HEADER="Metadata-Flavor: Google"

    PROJECT_ID=$(curl -s -H "$HEADER" "$METADATA/project/project-id")
    SERVICE_ACCOUNT_EMAIL=$(curl -s -H "$HEADER" "$METADATA/instance/service-accounts/default/email")
    ZONE_FULL=$(curl -s -H "$HEADER" "$METADATA/instance/zone")
    ZONE=${ZONE_FULL##*/}
    REGION=${ZONE%-*}

    echo "Project ID:            $PROJECT_ID"
    echo "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
    echo "Region:                $REGION"
    
    mkdir -p workspace &&
    cp ~{snakefile} workspace/Snakefile &&
    cp ~{script} workspace/check_file.py &&
    cp ~{env_yaml} workspace/snakemake-env.yaml &&
    cd workspace &&
    snakemake \
      --google-batch \
      --default-storage-prefix ~{remote_prefix} \
      --jobs 10 \
      --latency-wait 60 \
      --use-conda \
      --rerun-incomplete \
      --googlebatch-region $REGION \
      --googlebatch-service-account-email $SERVICE_ACCOUNT_EMAIL \
      --googlebatch-project $PROJECT_ID
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
