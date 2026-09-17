# Cloudflare Pages and DNS

OpenTofu manages the DNS zone, DNS records, Pages project, GitHub build settings, and custom domains. Cloudflare handles deployments and TLS certificates. No Netlify resources are deleted.

`terraform.tfvars.example` contains the supplied Netlify export's Hover MX/mail records and the `schema` subdomain, which stays on Netlify using a DNS-only CNAME. The export omitted MX priority; live DNS confirmed priority 10. No SPF, DKIM, or DMARC records were present in the export. Apex and `www` are deliberately omitted from `dns_records`: enable `pages_domains` before delegation. Keep the separate `schema` Netlify site running even after the main website has migrated.

## Prerequisites

- OpenTofu 1.11+.
- A Cloudflare account and API token with **Account / Cloudflare Pages / Edit**, **Zone / Zone / Edit**, and **Zone / DNS / Edit**. Zone creation needs permission to create a zone in the account; after creation, restrict zone permissions to this zone.
- Authorize the Cloudflare Pages GitHub app for `BjornDCode/bjornlindholm.com`. This interactive authorization cannot be done by OpenTofu. If linking GitHub requires creating the Pages project in the dashboard, use the name `bjornlindholm-com` and import it as shown below.
- Access to the domain registrar to change nameservers. Registrar delegation is outside the Cloudflare provider.
- A **full DNS export** from the existing NS1/Netlify DNS service, including mail, TXT verification, SPF/DKIM/DMARC, CAA, SRV, and subdomains. Public lookups and Cloudflare's DNS scan are not a complete inventory.

## 1. Prepare without switching traffic

From this directory:

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set account_id. Keep pages_domains empty for now.
export CLOUDFLARE_API_TOKEN='your-token'
tofu init
tofu fmt -check -recursive
tofu validate
tofu test
```

The token comes from the environment, not configuration or state. Tests use a mocked provider and do not call Cloudflare.

If the zone or project already exists in Cloudflare, import it **before** applying (replace placeholders):

```sh
tofu import cloudflare_zone.site ZONE_ID
tofu import cloudflare_pages_project.site ACCOUNT_ID/bjornlindholm-com
```

```sh
tofu plan -out=prepare.tfplan
tofu apply prepare.tfplan
tofu output pages_url
tofu output nameservers
```

This creates the zone and Pages project without changing nameservers or production DNS. Push the site's HTML conversion and these changes to GitHub `main` to trigger a production build; project creation alone is not proof of a deployment. Cloudflare runs `npm ci && npm run build` with Node 22 and publishes `pages/`. Other branches get preview deployments.

Check the `pages.dev` URL: home, articles, CSS, images, mobile menu, and the legacy `/product/using-airtable-as-a-backend.html` redirect. The existing `_redirects` file works on Pages and explicitly retains a 301 redirect.

Keep the ignored local state files backed up securely. They are necessary to manage the resources. Do not run from another checkout without transferring state or configuring a shared backend first. Commit `.terraform.lock.hcl`; never commit tokens, state, or saved plans.

## 2. Prepare DNS cutover

1. Save the original zone export, nameservers, and Netlify settings for rollback. Leave the Netlify site and old DNS zone running.
2. Populate `dns_records` in `terraform.tfvars` from the export. Preserve each record's name, type, content, TTL, and priority; use `data` for structured records such as SRV. Keep non-web records DNS-only (`proxied = false`, the default). Do not copy the old zone's SOA or apex NS records; Cloudflare supplies these. Preserve intentional subdomain NS delegations.
3. Do not copy apex or `www` A/AAAA/CNAME/Netlify ALIAS records when enabling those names in `pages_domains`: the dedicated Pages records replace them. Netlify ALIAS records for any other host need an appropriate Cloudflare equivalent, not a literal `ALIAS` type. Check CAA records permit Cloudflare's certificate issuance.
4. Set `pages_domains = ["bjornlindholm.com", "www.bjornlindholm.com"]`. Both hostnames serve the site; this does not add a canonical-host redirect.
5. Inspect the Cloudflare zone for automatically scanned or pre-existing records. Import matching records rather than creating duplicates, and explicitly resolve conflicting web records. For an existing record matching a `dns_records` key:

   ```sh
   tofu import 'cloudflare_dns_record.existing["mail"]' ZONE_ID/RECORD_ID
   ```

   Existing Pages CNAME records can instead be imported into `cloudflare_dns_record.pages["bjornlindholm.com"]`. Already-attached domains import into `cloudflare_pages_domain.site["bjornlindholm.com"]` using `ACCOUNT_ID/bjornlindholm-com/bjornlindholm.com`.

6. Review and apply:

   ```sh
   tofu plan -out=cutover.tfplan
   tofu apply cutover.tfplan
   ```

   Custom domains may remain pending until delegation and certificate validation finish. If importing/replacing previously managed web records, review deletions carefully: old A/AAAA records must not coexist with the new CNAME. Do not approve unrelated DNS changes.

7. Compare **every** record in the original export against the new zone, allowing only the intentional website changes. Do not change nameservers with an empty or incomplete inventory. Neither this configuration nor OpenTofu can detect records missing from an export.

## 3. Delegate and verify

If DNSSEC is enabled at the old provider, remove the old DS record at the registrar and allow its TTL to expire **before** changing nameservers. Leaving it in place can make the domain fail DNS validation. Re-enable DNSSEC with Cloudflare and publish its new DS only after the migration is stable; DNSSEC is not enabled by this configuration.

At the registrar, replace the existing nameservers with `tofu output nameservers`. Keep the original provider serving its zone during propagation. TLS activation can take time; monitor both Pages custom domains until they are active.

```sh
dig NS bjornlindholm.com
dig MX bjornlindholm.com
dig TXT bjornlindholm.com
curl -I https://bjornlindholm.com/
curl -I https://www.bjornlindholm.com/
curl -I https://bjornlindholm.com/style.css
curl -I https://bjornlindholm.com/product/using-airtable-as-a-backend.html
```

Also verify DKIM/DMARC, all subdomains, inbound/outbound mail, and representative site pages. Run `tofu plan` again to check for drift. Only retire Netlify after propagation, successful checks, and a suitable rollback window.

## Rollback

Restore the saved nameservers at the registrar while the original zone and Netlify site still exist. DNS caches mean rollback is not immediate. Coordinate DS records with whichever DNS provider is authoritative; never restore a stale DS record against Cloudflare nameservers. Do not use `tofu destroy` as a rollback: it would remove DNS records and custom domains. The zone and Pages project have `prevent_destroy` protection, but records still require careful plan review.
