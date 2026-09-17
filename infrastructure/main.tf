terraform {
  required_version = ">= 1.11.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.25.0"
    }
  }
}

# Authentication comes from CLOUDFLARE_API_TOKEN, never from committed files.
provider "cloudflare" {}

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "dns_records" {
  description = "Existing DNS inventory to preserve, keyed by stable record names. Exclude records managed by pages_domains."
  type = map(object({
    name     = string
    type     = string
    content  = optional(string)
    data     = optional(map(string))
    ttl      = optional(number, 300)
    priority = optional(number)
    proxied  = optional(bool, false)
  }))
  default = {}
}

variable "pages_domains" {
  description = "Domains ready to point at Pages. Leave empty until the Pages deployment has been verified."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for domain in var.pages_domains : contains(["bjornlindholm.com", "www.bjornlindholm.com"], domain)])
    error_message = "Only bjornlindholm.com and www.bjornlindholm.com are supported."
  }
}

resource "cloudflare_zone" "site" {
  account = { id = var.account_id }
  name    = "bjornlindholm.com"
  type    = "full"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "existing" {
  for_each = var.dns_records

  zone_id  = cloudflare_zone.site.id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  data     = each.value.data
  ttl      = each.value.ttl
  priority = each.value.priority
  proxied  = each.value.proxied
}

resource "cloudflare_pages_project" "site" {
  account_id        = var.account_id
  name              = "bjornlindholm-com"
  production_branch = "main"

  build_config = {
    build_command   = "npm ci && npm run build"
    destination_dir = "pages"
    root_dir        = ""
  }

  source = {
    type = "github"
    config = {
      owner                          = "BjornDCode"
      repo_name                      = "bjornlindholm.com"
      production_branch              = "main"
      production_deployments_enabled = true
      pr_comments_enabled            = true
      preview_deployment_setting     = "all"
    }
  }

  deployment_configs = {
    production = {
      env_vars = {
        NODE_VERSION            = { type = "plain_text", value = "22" }
        SKIP_DEPENDENCY_INSTALL = { type = "plain_text", value = "true" }
      }
    }
    preview = {
      env_vars = {
        NODE_VERSION            = { type = "plain_text", value = "22" }
        SKIP_DEPENDENCY_INSTALL = { type = "plain_text", value = "true" }
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_pages_domain" "site" {
  for_each = var.pages_domains

  account_id   = var.account_id
  project_name = cloudflare_pages_project.site.name
  name         = each.value
}

resource "cloudflare_dns_record" "pages" {
  for_each = var.pages_domains

  zone_id = cloudflare_zone.site.id
  name    = cloudflare_pages_domain.site[each.key].name
  type    = "CNAME"
  content = cloudflare_pages_project.site.subdomain
  proxied = true
  ttl     = 1
}

output "nameservers" {
  value = cloudflare_zone.site.name_servers
}

output "pages_url" {
  value = "https://${cloudflare_pages_project.site.subdomain}"
}

output "zone_id" {
  value = cloudflare_zone.site.id
}
