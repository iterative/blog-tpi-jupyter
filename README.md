# Terraform Provider Iterative + Jupyter + TensorBoard

Painlessly deploy an ML-ready Jupyter server and sync results with your favourite cloud compute provider.

```sh
terraform init --upgrade     # Setup local dependencies
terrafrom apply              # Create cloud resources & upload "shared" workdir
terraform refresh | grep URL # Get Jupyter & TensorBoard URLs
# ...
# Have fun!
# (optional) Click "Quit" in Jupyter to shutdown the cloud machine
# ...
terraform destroy            # Download "shared" & terminate cloud resources
```

Note that it can take a couple of minutes after `apply` for the machine to be ready.

## Requirements

[`terraform`](https://www.terraform.io/downloads.html) plus some environment variables:

- `NGROK_TOKEN`: sign up for free at https://ngrok.com
- `JUPYTER_PASSWORD`: whatever you wish
- Cloud credentials ([AWS], [Azure], [GCP], or [Kubernetes]). For example:
  + `AWS_ACCESS_KEY_ID`
  + `AWS_SECRET_ACCESS_KEY`

[AWS]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#amazon-web-services
[Azure]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#microsoft-azure
[GCP]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#google-cloud-platform
[Kubernetes]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#kubernetes
