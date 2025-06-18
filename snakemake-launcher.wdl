version 1.0

workflow SnakemakeBatchLauncher {
  call RunSnakemakeBatch
}

task RunSnakemakeBatch {
  input {
    File snakefile
    File script
    File inputs
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
    
    ls

    mkdir -p workspace &&
    cp ~{snakefile} workspace/Snakefile &&Add commentMore actions
    cp ~{script} workspace/check_file.py &&
    cp ~{inputs} workspace/gcs_paths.txt &&
    cp ~{env_yaml} workspace/snakemake-env.yaml &&
    cd workspace

    snakemake \
      --executor googlebatch \
      --default-storage-provider gcs \
      --default-storage-prefix ~{remote_prefix} \
      --storage-gcs-project $PROJECT_ID \
      --jobs 10 \
      --latency-wait 60 \
      --use-conda \
      --rerun-incomplete \
      --googlebatch-region $REGION \
      --googlebatch-service-account $SERVICE_ACCOUNT_EMAIL \
      --googlebatch-project $PROJECT_ID \
      --googlebatch-network global/networks/network \
      --googlebatch-subnetwork regions/us-central1/subnetworks/subnetwork \
      --googlebatch-boot-disk-image projects/cloud-hpc-image-public/global/images/family/hpc-rocky-linux-8

    ls
  >>>

  runtime {
    docker: docker_image
    memory: "4G"
    cpu: 2
  }

  output {
    Array[File] ws_log = glob("workspace/.snakemake/log/*.log")
    Array[File] ws_batch_log = glob("workspace/.snakemake/googlebatch_logs/*.log")
    Array[File] log = glob(".snakemake/log/*.log")
    Array[File] batch_log = glob(".snakemake/googlebatch_logs/*.log")
  }
}
