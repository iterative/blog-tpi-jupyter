# Config file for running a Jupter server in the cloud with one command!
# Low-cost, custom-spec, auto-backed-up & restarted/recovered cloud compute.
#
# Requirements:
# 1. `terraform` (https://www.terraform.io/downloads.html)
# 2. some env vars
#   - cloud account (https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication)
#   - https://ngrok.com token (NGROK_TOKEN)
#   - any choice of password (JUPYTER_PASSWORD)
#
# Usage:
# 0. `terraform init --upgrade` to setup deps
# 1. `terraform apply` to create cloud resources & upload `./shared/` workdir
# 2. `terraform refresh`
# 3. click on the URL printed on the console to open Jupyter
#    (wait a minute and repeat step 2 if there's no URL)
# 4. (optional) click "Quit" in Jupyter to shutdown the cloud machine
# 5. `terraform destroy` to download the `./shared/` workdir & terminate cloud resources
terraform {
  required_providers { iterative = { source = "iterative/iterative" } }
}
provider "iterative" {}

# For a full list of options, see:
# https://registry.terraform.io/providers/iterative/iterative/latest/docs/resources/task
resource "iterative_task" "jupyter_server" {
  spot      = 0            # auto-priced low-cost spot instance
  timeout   = 60*60*24     # force shutdown after 24h
  disk_size = 125          # GB

  # cloud-specific config
  cloud     = "aws"          # or any of: gcp, az, k8s
  machine   = "g4dn.xlarge"  # NVIDIA Tesla T4 GPU, 4 CPUs & 125 GB NVMe SSD at ~$0.15/h
  image     = "user@*:x86_64:Deep Learning AMI GPU TensorFlow 2.7.0 (Ubuntu 20.04) 20211208"

  # blank means extract from local env vars
  environment = { NGROK_TOKEN = "", JUPYTER_PASSWORD = "", CUDACXX = "/usr/local/cuda/bin/nvcc" }
  storage {
    workdir = "shared"
    output  = "."
  }
  script = <<-END
    #!/bin/bash
    set -euo pipefail
    # install deps
    pip3 install notebook tensorflow tensorboard
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt install -yqq nodejs

    # start tunnel
    pushd "$(mktemp -d --suffix ngrok-tunnel)"
    npm i ngrok
    npx ngrok authtoken "$NGROK_TOKEN"
    (node <<-EOF
    const fs = require('fs');
    const ngrok = require('ngrok');
    (async function() {
      const jupyter = await ngrok.connect(8888);
      const tensorboard = await ngrok.connect(6006);
      fs.writeFileSync("log.md", \`URL: Jupyter Notebook: \$${jupyter} TensorBoard: \$${tensorboard}\n\`);
    })();
    EOF
    ) &
    while [[ ! -f log.md ]]; do sleep 1; done
    cat log.md
    popd

    # start tensorboard in background
    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN PASSWORD="$JUPYTER_PASSWORD" tensorboard --logdir . --host 0.0.0.0 --port 6006 &

    # start Jupyter server in foreground
    mkdir -p ~/.jupyter
    echo '{
      "NotebookApp": {
        "allow_root": true, "ip": "0.0.0.0", "open_browser": false,
        "password": "'$(python3 -c "from IPython.lib import passwd; print(passwd('$JUPYTER_PASSWORD'), end='')")'",
        "password_required": true, "port": 8888, "port_retries": 0,
        "shutdown_no_activity_timeout": 86400
      }
    }' > ~/.jupyter/jupyter_notebook_config.json
    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN jupyter notebook
  END
}
output "logs" {
  value = try(join("\n", iterative_task.jupyter_server.logs), "")
}
