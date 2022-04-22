# Terraform Provider Iterative + Jupyter + TensorBoard

![](https://static.iterative.ai/img/tpi/banner-blog-jupyter.png)

Painlessly deploy an ML-ready Jupyter server and sync results with your preferred cloud compute provider.

To get started, clone this repo, then in the repo directory run:

```sh
export NGROK_TOKEN="..."     # Sign up for free at https://ngrok.com
export TF_LOG_PROVIDER=INFO  # (optional) Control verbosity
terraform init               # Setup local dependencies
terraform apply              # Create cloud resources & upload "shared" workdir
terraform refresh            # Get Jupyter & TensorBoard URLs
# ...
# Have fun!
# (optional) Click "Quit" in Jupyter to shutdown the cloud machine
# ...
terraform destroy # Download "shared" workdir & terminate cloud resources
```

🛈 Note that it can take a couple of minutes after `apply` for the machine to be ready.

🛈 Note that [Terraform Provider Iterative (TPI)](https://github.com/iterative/terraform-provider-iterative) will automatically restart interrupted spot/preemptible instances (including restoring Jupyter's working directory). In such cases, run `terraform refresh` again to obtain the new Jupyter & TensorBoard URLs.

## Requirements

Toggle Version: [![](https://img.shields.io/badge/aws-other_clouds-grey.svg?colorA=blue)](https://github.com/iterative/blog-tpi-jupyter/tree/generic#requirements)
<!-- `git checkout generic` for Azure, GCP & K8s -->

- Download [`terraform`](https://www.terraform.io/downloads.html) (free)
- [ngrok](https://ngrok.com) credentials (free)
- Cloud credentials ([AWS], [Azure], [GCP], or [Kubernetes]). For example:
  + `AWS_ACCESS_KEY_ID`
  + `AWS_SECRET_ACCESS_KEY`

[AWS]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#amazon-web-services
[Azure]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#microsoft-azure
[GCP]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#google-cloud-platform
[Kubernetes]: https://registry.terraform.io/providers/iterative/iterative/latest/docs/guides/authentication#kubernetes

## Alternatives

Some that we are aware of: (Anything missing? Please do open a PR!)

- [Google Colab](https://colab.research.google.com/): based on (but not identical to) Jupyter, has [resource limits](https://research.google.com/colaboratory/faq.html#resource-limits) and limited config options (CPU, GPU, RAM, memory, timeouts)
- [Binder](https://mybinder.org/): no GPU, no config options, for-profit use disallowed, has [user guidelines](https://mybinder.readthedocs.io/en/latest/about/user-guidelines.html)

However there are a few distinct advantages to using `terraform` over the alternatives:

- **Lower cost**: use your preferred cloud provider's existing pricing, including on-demand per-second billing and bulk discounts
- **Auto-recovery**: auto-backup `workdir` & auto-recover terminated `spot` instances
- **Custom spec**: full control over hardware & software requirements via `main.tf` -- including machine [types](https://registry.terraform.io/providers/iterative/iterative/latest/docs/resources/task#machine-type) (CPU, GPU, RAM, storage) & [images](https://registry.terraform.io/providers/iterative/iterative/latest/docs/resources/task#machine-image)
