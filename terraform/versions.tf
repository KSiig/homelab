terraform {
  required_version = ">= 1.0"

  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
}
