# Mocked plans only: these tests never contact Cloudflare or create resources.
mock_provider "cloudflare" {}

variables {
  account_id = "00000000000000000000000000000000"
}

run "prepare_without_cutover" {
  command = plan

  assert {
    condition     = length(cloudflare_pages_domain.site) == 0 && length(cloudflare_dns_record.pages) == 0
    error_message = "The initial apply must not route custom domains to Pages."
  }

  assert {
    condition     = cloudflare_pages_project.site.build_config.destination_dir == "pages" && cloudflare_pages_project.site.source.config.production_deployments_enabled
    error_message = "Production pushes must build and deploy pages/."
  }
}

run "cutover_preserves_mail" {
  command = plan

  variables {
    pages_domains = ["bjornlindholm.com", "www.bjornlindholm.com"]
    dns_records = {
      mail = {
        name     = "bjornlindholm.com"
        type     = "MX"
        content  = "mail.example.com"
        priority = 10
      }
    }
  }

  assert {
    condition     = length(cloudflare_pages_domain.site) == 2 && length(cloudflare_dns_record.pages) == 2
    error_message = "Both hostnames need a Pages domain and DNS record."
  }

  assert {
    condition     = cloudflare_dns_record.existing["mail"].content == "mail.example.com" && cloudflare_dns_record.existing["mail"].priority == 10 && !cloudflare_dns_record.existing["mail"].proxied
    error_message = "Cutover must preserve DNS-only mail records."
  }
}
