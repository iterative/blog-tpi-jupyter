# Terraform Provider Iterative + Jupyter + Tensorboard

Painlessly deploy an ML-ready Jupyter server and sync results with your favourite cloud compute provider.

Command             |Description
:-------------------|:----------
`terraform init`    | Install
`terrafrom apply`   | Create remote instance & upload "shared" working dir
`terraform refresh && terraform show \| grep URL` |  Get Jupyter & Tensorboard URLs
`terraform destroy` | Download "shared" dir and terminate remote instance

## Requirements

[`terraform`](https://www.terraform.io/downloads.html) plus some environment variables:

- `NGROK_TOKEN`: sign up for free at https://ngrok.com
- `JUPYTER_PASSWORD`: whatever you wish
- Cloud credentials ([AWS], [Azure], [GCP], or [Kubernetes]). For example:
  + `AWS_ACCESS_KEY_ID`
  + `AWS_SECRET_ACCESS_KEY`

[AWS]: https://registry.terraform.io/providers/iterative/iterative/latest/docs#amazon-web-services
[Azure]: https://registry.terraform.io/providers/iterative/iterative/latest/docs#microsoft-azure
[GCP]: https://registry.terraform.io/providers/iterative/iterative/latest/docs#google-cloud-platform
[Kubernetes]: https://registry.terraform.io/providers/iterative/iterative/latest/docs#kubernetes
