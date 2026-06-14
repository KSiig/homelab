provider "flux" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
  git = {
    url = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
    ssh = {
      username    = "git"
      private_key = file(pathexpand("~/.ssh/id_ed25519"))
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

resource "flux_bootstrap_git" "this" {
  path = "clusters/home"
}
