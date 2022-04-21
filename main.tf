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
# 1. terraform init    # Setup local dependencies
# 2. terrafrom apply   # Create cloud resources & upload "shared" workdir
# 3. terraform refresh | grep URL # Get Jupyter & TensorBoard URLs
# 4. (optional) click "Quit" in Jupyter to shutdown the cloud machine
# 5. terraform destroy # Download "shared" workdir & terminate cloud resources
terraform {
  required_providers { iterative = { source = "iterative/iterative" } }
}
provider "iterative" {}

# For a full list of options, see:
# https://registry.terraform.io/providers/iterative/iterative/latest/docs/resources/task
resource "iterative_task" "jupyter_server" {
  spot      = 0             # auto-priced low-cost spot instance
  timeout   = 60*60*24      # force shutdown after 24h
  disk_size = 125           # GB
  region    = "us-east"

  # cloud-specific config
  cloud     = "aws"         # or any of: gcp, az, k8s
  machine   = "g4dn.xlarge" # NVIDIA Tesla T4 GPU, 4 CPUs & 125 GB NVMe SSD at ~$0.15/h
  image     = "user@898082745236:x86_64:Deep Learning AMI GPU TensorFlow 2.8.0 (Ubuntu 20.04) 20220315"

  # blank means extract from local env vars
  environment = { NGROK_TOKEN = "", QUIET = "1" }
  storage {
    workdir = "shared"
    output  = "."
  }
  script = <<-END
    #!/bin/bash
    set -euo pipefail
    export CUDACXX=/usr/local/cuda/bin/nvcc
    export DEBIAN_FRONTEND=noninteractive
    sed -ri 's#^(APT::Periodic::Unattended-Upgrade).*#\1 "0";#' /etc/apt/apt.conf.d/20auto-upgrades
    dpkg-reconfigure unattended-upgrades
    # install dependencies
    pip3 install $${QUIET:+-q} notebook matplotlib ipywidgets tensorflow==2.8.0 tensorboard tensorflow_datasets
    (curl -fsSL https://deb.nodesource.com/setup_16.x | bash -) >> /dev/null
    apt-get install -y $${QUIET:+-qq} nodejs

    # start tunnel
    export JUPYTER_TOKEN="$(uuidgen)"
    pushd "$(mktemp -d --suffix dependencies)"
    npm i ngrok
    npx ngrok authtoken "$NGROK_TOKEN"
    (node <<EOF
    const fs = require('fs');
    const ngrok = require('ngrok');
    (async function() {
      const jupyter = await ngrok.connect(8888);
      const tensorboard = await ngrok.connect(6006);
      const br = '\n*=*=*=*=*=*=*=*=*=*=*=*=*\n';
      fs.writeFileSync("log.md", \`\$${br}URL: Jupyter Lab: \$${jupyter}/lab?token=$${JUPYTER_TOKEN}\$${br}URL: Jupyter Notebook: \$${jupyter}/tree?token=$${JUPYTER_TOKEN}\$${br}URL: TensorBoard: \$${tensorboard}\$${br}\`);
    })();
    EOF
    ) &
    while test ! -f log.md; do sleep 1; done
    cat log.md
    popd # dependencies

    # start tensorboard in background
    env -u JUPYTER_TOKEN -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN tensorboard --logdir . --host 0.0.0.0 --port 6006 &

    # start Jupyter server in foreground
    mkdir ~/.jupyter
    echo '{
      "ServerApp": {
        "allow_root": true, "ip": "0.0.0.0", "open_browser": false,
        "port": 8888, "port_retries": 0, "token": "'$JUPYTER_TOKEN'"
      }
    }' > ~/.jupyter/jupyter_notebook_config.json
    env -u JUPYTER_TOKEN -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN jupyter lab
  END
}
output "logs" {
  value = try(join("\n", iterative_task.jupyter_server.logs), "")
}
