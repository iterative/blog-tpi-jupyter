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
  machine   = "m+t4"        # m/l/xl (CPU), +k80/t4/v100 (GPU)
  image     = "nvidia"      # or "ubuntu"

  # cloud-specific config
  cloud     = "aws"         # see `git checkout generic` branch for: gcp, az, k8s

  # blank means extract from local env vars
  environment = { NGROK_TOKEN = "", TF_CPP_MIN_LOG_LEVEL = "1", QUIET = "1", GITHUB_USER = "" }
  storage {
    workdir = "shared"
    output  = "."
  }
  script = <<-END
    #!/bin/bash
    set -euo pipefail
    if test -n "$GITHUB_USER"; then
      # SSH debugging
      trap 'echo script error: waiting for debugging over SSH. Run \"terraform destroy\" to stop waiting; sleep inf' ERR
      mkdir -p "$HOME/.ssh"
      curl -fsSL "https://github.com/$GITHUB_USER.keys" >> "$HOME/.ssh/authorized_keys"
    fi
    export CUDACXX=/usr/local/cuda/bin/nvcc
    export DEBIAN_FRONTEND=noninteractive
    sed -ri 's#^(APT::Periodic::Unattended-Upgrade).*#\1 "0";#' /etc/apt/apt.conf.d/20auto-upgrades
    dpkg-reconfigure unattended-upgrades
    # install dependencies
    pip3 install $${QUIET:+-q} jupyterlab notebook matplotlib ipywidgets tensorflow==2.8.0 tensorboard tensorflow_datasets
    (curl -fsSL https://deb.nodesource.com/setup_16.x | bash -) >/dev/null
    apt-get install -y $${QUIET:+-qq} nodejs

    # start tunnel
    export JUPYTER_TOKEN="$(uuidgen)"
    pushd "$(mktemp -d --suffix dependencies)"
    npm i ngrok
    npx ngrok authtoken "$NGROK_TOKEN"
    (node <<TUNNEL
    const fs = require('fs');
    const ngrok = require('ngrok');
    (async function() {
      const jupyter = await ngrok.connect(8888);
      const tensorboard = await ngrok.connect(6006);
      const br = '\n*=*=*=*=*=*=*=*=*=*=*=*=*\n';
      fs.writeFileSync("log.md", \`\$${br}URL: Jupyter Lab: \$${jupyter}/lab?token=$${JUPYTER_TOKEN}\$${br}URL: Jupyter Notebook: \$${jupyter}/tree?token=$${JUPYTER_TOKEN}\$${br}URL: TensorBoard: \$${tensorboard}\$${br}\`);
    })();
    TUNNEL
    ) &
    while test ! -f log.md; do sleep 1; done
    cat log.md
    popd # dependencies

    # start tensorboard in background
    env -u JUPYTER_TOKEN -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN tensorboard --logdir . --host 0.0.0.0 --port 6006 &

    # start Jupyter server in foreground
    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN jupyter lab --allow-root --ip=0.0.0.0 --no-browser --port=8888 --port-retries=0
  END
}
output "urls" {
  value = flatten(regexall("URL: (.+)", try(join("\n", iterative_task.jupyter_server.logs), "")))
}
