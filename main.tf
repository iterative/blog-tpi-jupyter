terraform {
  required_providers { iterative = { source = "iterative/iterative", version = ">= 0.9.9" } }
}
provider "iterative" {}
resource "iterative_task" "jupyter_server" {
  name    = "casper"
  cloud   = "aws"
  machine = "g4dn.xlarge"
  image   = "user@*:x86_64:Deep Learning AMI GPU TensorFlow 2.7.0 (Ubuntu 20.04) 20211208"

  environment = { NGROK_TOKEN = "", JUPYTER_PASSWORD = "", CUDACXX = "/usr/local/cuda/bin/nvcc" }
  workdir { input = "${path.root}/shared" }
  script = <<-END
    #!/bin/bash
    set -euo pipefail
    pip3 install notebook tensorflow tensorboard cuvec
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt install -yqq nodejs

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

    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN PASSWORD="$JUPYTER_PASSWORD" tensorboard --logdir . --host 0.0.0.0 --port 6006 &

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
