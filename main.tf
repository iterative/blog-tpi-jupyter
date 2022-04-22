# Config file for running a Jupter server in the cloud with one command!
# Low-cost, custom-spec, auto-backed-up & restarted/recovered cloud compute.
#
# Requirements:
# 1. `terraform` (https://www.terraform.io/downloads.html)
# 2. some env vars
#   - cloud account (https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication)
#   - https://ngrok.com token (NGROK_TOKEN)
#
# Usage:
# 1. terraform init      # Setup local dependencies
# 2. terraform apply     # Create cloud resources & upload "shared" workdir
# 3. terraform refresh   # Get Jupyter & TensorBoard URLs
# 4. (optional) click "Quit" in Jupyter to shutdown the cloud machine
# 5. terraform destroy   # Download "shared" workdir & terminate cloud resources
terraform {
  required_providers { iterative = { source = "iterative/iterative" } }
}
provider "iterative" {}

# For a full list of options, see:
# https://registry.terraform.io/providers/iterative/iterative/latest/docs/resources/task
resource "iterative_task" "jupyter_server" {
  spot      = 0             # auto-priced low-cost spot instance
  timeout   = 24*60*60      # force shutdown after 24h
  disk_size = 125           # GB
  machine   = "m+k80"       # m or l (CPU), +k80 or +v100 (GPU)
  image     = "nvidia"      # or "ubuntu"

  # cloud-specific config
  cloud     = "aws"         # or any of: gcp, az, k8s

  # blank means extract from local env vars
  environment = { NGROK_TOKEN = "", TF_CPP_MIN_LOG_LEVEL = "1", QUIET = "1", GITHUB_USER = "username" }
  storage {
    workdir = "shared"
    output  = "."
  }
  script = <<-END
    #!/bin/bash
    set -euo pipefail
    if test "$GITHUB_USER" != username; then
      # SSH debugging
      trap 'echo script error: waiting for debugging over SSH. Run \"terraform destroy\" to stop waiting; sleep inf' ERR
      mkdir -p "$HOME/.ssh"
      curl -fsSL "https://github.com/$GITHUB_USER.keys" >> "$HOME/.ssh/authorized_keys"
    fi

    # create dependency files
    pushd "$(mktemp -d --suffix dependencies)"

    (cat <<CMD
    #!/bin/bash
    set -euo pipefail
    # start tunnel in background
    npx ngrok authtoken "\$NGROK_TOKEN"
    (node <<TUNNEL
    const fs = require('fs');
    const ngrok = require('ngrok');
    const { JUPYTER_TOKEN } = process.env;
    (async function() {
      const jupyter = await ngrok.connect(8888);
      const tensorboard = await ngrok.connect(6006);
      const br = '\n*=*=*=*=*=*=*=*=*=*=*=*=*\n';
      fs.writeFileSync("log.md", \\\`\\\$${br}URL: Jupyter Lab: \\\$${jupyter}/lab?token=\\\$${JUPYTER_TOKEN}\\\$${br}URL: Jupyter Notebook: \\\$${jupyter}/tree?token=\\\$${JUPYTER_TOKEN}\\\$${br}URL: TensorBoard: \\\$${tensorboard}\\\$${br}\\\`);
    })();
    TUNNEL
    ) &
    while test ! -f log.md; do sleep 1; done
    cat log.md
    # start tensorboard in background
    tensorboard --logdir . --host 0.0.0.0 --port 6006 &
    # start Jupyter server in foreground
    jupyter lab --allow-root --ip=0.0.0.0 --notebook-dir=/server --no-browser --port=8888 --port-retries=0
    CMD
    ) >cmd.sh

    (cat <<DOCKERFILE
    FROM tensorflow/tensorflow:latest-gpu-jupyter
    ARG QUIET=1
    RUN python3 -m pip install --no-cache-dir \$${QUIET:+-q} jupyterlab 'nbformat>=5.2' matplotlib ipywidgets tensorboard tensorflow_datasets
    RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - >>/dev/null && apt-get install -y \$${QUIET:+-qq} nodejs && npm i ngrok
    COPY cmd.sh ./
    RUN chmod +x cmd.sh
    CMD ["./cmd.sh"]
    DOCKERFILE
    ) >Dockerfile

    # build docker image
    docker pull $${QUIET:+-q} tensorflow/tensorflow:latest-gpu-jupyter
    docker build -t img --build-arg QUIET="$QUIET" .

    popd # dependencies
    docker run --gpus all --rm -i -e NGROK_TOKEN -e JUPYTER_TOKEN="$(uuidgen)" -p 6006:6006 -p 8888:8888 -v "$PWD:/server" img
  END
}
output "urls" {
  value = flatten(regexall("URL: (.+)", try(join("\n", iterative_task.jupyter_server.logs), "")))
}
