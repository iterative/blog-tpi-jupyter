terraform {
  required_providers {
    iterative = {
      source = "iterative/iterative"
    }
  }
}

provider "iterative" {}

resource "iterative_task" "casper_jupyter" {
  name    = "casper_jupyter"
  cloud   = "aws"
  machine = "g4dn.xlarge"
  image   = "user@*:x86_64:Deep Learning AMI GPU TensorFlow 2.7.0 (Ubuntu 20.04) 20211208"

  environment = { NGROK_TOKEN = "", JUPYTER_PASSWORD = "" }
  directory   = "${path.root}/shared"
  script      = <<-END
    #!/bin/bash
    pip install notebook tensorflow tensorboard cuvec

    npm i ngrok
    if [[ -n "$NGROK_TOKEN" ]]; then npx ngrok authtoken "$NGROK_TOKEN"; fi
    npx ngrok version
    rm -f shared/log.md
    node tunnel.js &
    echo waiting for log.md
    while [[ ! -f log.md ]]; do sleep 1; done

    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN PASSWORD="$JUPYTER_PASSWORD" tensorboard --logdir . --host 0.0.0.0 --port 6006 &

    JUPYTER_SHA="$(python -c "from IPython.lib import passwd; print(passwd('$JUPYTER_PASSWORD'), end='')")"
    mkdir -p ~/.jupyter
    echo '{
      "NotebookApp": {
        "allow_root": true, "ip": "0.0.0.0", "open_browser": false,
        "password": "'$JUPYTER_SHA'", "password_required": true,
        "port": 8888, "port_retries": 0,
        "shutdown_no_activity_timeout": 86400
      }
    }' > ~/.jupyter/jupyter_notebook_config.json
    env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u REPO_TOKEN jupyter notebook
  END
}
