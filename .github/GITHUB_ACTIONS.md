# GitHub Actions - Infrastructure Automation

Automated OCI infrastructure provisioning using Terraform in GitHub Actions workflows.

**Cost:** $0.00/month (Always Free tier)  
**Setup Time:** 5 minutes  
**Deployment Time:** 10-15 minutes

---

## Quick Start

### 1. Configure Secrets

**Settings → Secrets and Variables → Actions → Secrets**

```
OCI_COMPARTMENT_OCID     # Required: Your OCI compartment OCID
DB_ADMIN_PASSWORD        # Optional: Auto-generated if not provided
```

### 2. Create Environments

**Settings → Environments**

Create `production` environment:
- Add required reviewers (yourself/team)
- Optional: Set wait timer (e.g., 5 minutes)

### 3. Deploy

**Actions → "Provision OCI Infrastructure" → Run workflow**

```bash
# First time: Review plan
Action: plan → Run → Review output

# When ready: Deploy
Action: apply → Run → Approve gate → Infrastructure deployed
```

---

## Architecture: Direct Terraform Execution

**This workflow runs Terraform directly—no Ansible wrapper in CI/CD.**

### Why This Approach?

| Direct Terraform (CI/CD) | Ansible + Terraform (Local) |
|-------------------------|------------------------------|
| ✅ Industry standard | ⚠️ Niche use case |
| ✅ Native GitHub Actions support | ⚠️ Extra orchestration layer |
| ✅ Simple, fast execution | ⚠️ More complex pipeline |
| ✅ Better debugging/logs | ⚠️ Harder to debug |
| ✅ Official HashiCorp action | ⚠️ Custom implementation |

### When to Use Each

**GitHub Actions (Terraform):**
- ✅ CI/CD pipelines
- ✅ Automated deployments
- ✅ Team collaboration
- ✅ Audit trails

**Ansible (Local):**
- ✅ Interactive development
- ✅ Multi-tool orchestration
- ✅ Custom validation workflows
- ✅ Complex local setups

---

## Workflow Triggers

### Automatic (No Manual Action)

| Trigger | What Happens | Changes Applied? |
|---------|--------------|------------------|
| **Pull Request** | Validates + Plans | ❌ No |
| **Push to main** | Validates + Plans | ❌ No |

Both automatically comment plan results on PRs for review.

### Manual (Requires Action)

| Action | What Happens | Approval Required? |
|--------|--------------|-------------------|
| **plan** | Review changes | ❌ No |
| **apply** | Deploy infrastructure | ✅ Yes (production env) |
| **destroy** | Delete everything | ✅ Yes (destroy env recommended) |

---

## Workflow Jobs

```
┌─────────────────────┐
│ validate-free-tier  │  Validates Always Free config
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│   terraform-plan    │  Plans infrastructure changes
│  - Format check     │
│  - Init & validate  │
│  - Create plan      │
│  - Comment on PR    │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│  terraform-apply    │  Applies changes (manual trigger)
│  - Requires approval│
│  - Uses saved plan  │
│  - Uploads outputs  │
└─────────────────────┘

┌─────────────────────┐
│ terraform-destroy   │  Destroys infrastructure (separate job)
│  - Requires approval│
│  - Permanent action │
└─────────────────────┘
```

---

## Security

### Secrets Configuration

| Secret | Required? | Purpose |
|--------|-----------|---------|
| `OCI_COMPARTMENT_OCID` | ✅ Yes | Deployment target |
| `DB_ADMIN_PASSWORD` | ⚠️ Optional | DB password (auto-gen if empty) |

**Find Compartment OCID:** OCI Console → Identity → Compartments

### Protection Mechanisms

1. **Environment Approval Gates**
   - `production` env → Requires reviewers for apply
   - `destroy` env → Recommended: multiple reviewers

2. **Always Free Tier Validation**
   - Automated check before any Terraform operation
   - Fails fast if config violates free tier limits

3. **Concurrency Control**
   - Prevents simultaneous Terraform runs
   - Branch-based locking

4. **No Hardcoded Secrets**
   - All credentials in GitHub Secrets
   - Never committed to repository

---

## Cost Protection

**Always Free tier enforcement (hardcoded in variables.tf):**

```hcl
cpu_core_count        = 1        # Cannot override
storage_size_tbs      = 0.02     # 20GB max
auto_scaling_enabled  = false    # Must be disabled
is_free_tier         = true      # Always Free
```

**Workflow validates before every run. Estimated cost: $0.00/month**

---

## Common Tasks

### View Deployment Status

```
Actions → Latest run → Job logs
```

### Download Outputs

```
Actions → Workflow run → Artifacts → "terraform-outputs"
```

### Destroy Infrastructure

⚠️ **Permanent deletion of all resources**

```
Actions → "Provision OCI Infrastructure" → Run workflow
Action: destroy → Approve
```

---

## Resources Created

| Resource | Specification | Free Tier Limit |
|----------|---------------|-----------------|
| Autonomous Database | 1 OCPU, 20GB | 2 per tenancy |
| Object Storage | Standard | 20GB total |
| VCN & Networking | Basic | Always Free |

---

## Troubleshooting

### Workflow Not Found

**Check:**
- Correct branch selected
- `.github/workflows/provision-infrastructure.yml` exists

### Secret Not Found

**Fix:**
```
Settings → Secrets → Verify names match exactly (case-sensitive)
Required: OCI_COMPARTMENT_OCID
```

### Environment Not Found

**Fix:**
```
Settings → Environments → Create "production" environment
Add required reviewers
```

### Terraform Plan Failed

**Check:**
1. OCI credentials valid
2. Compartment OCID correct
3. Review workflow logs for specific error
4. Verify Always Free tier eligibility

### State Lock Errors

**Cause:** Concurrent Terraform execution

**Fix:**
- Wait for other runs to complete
- Check for stuck locks in backend
- Use `terraform force-unlock` locally (caution)

---

## Outputs After Deployment

```bash
terraform output                  # View all outputs
```

**Available:**
- `database_id` - Database OCID
- `database_connection_strings` - Connection URLs
- `admin_username` - ADMIN
- `admin_password` - Sensitive
- `service_console_url` - OCI Console link
- `bucket_name` - Storage bucket

---

## Maintenance

### Updating Workflow

1. Create feature branch
2. Modify `.github/workflows/provision-infrastructure.yml`
3. Open PR → Review → Merge
4. Test in non-production first

### Monitoring

- Review Actions tab regularly
- Check for failed runs
- Verify OCI costs = $0.00
- Keep Terraform version current

---

## Best Practices

✅ **Always run plan first** before apply
✅ **Review workflow logs** even for successful runs  
✅ **Enable branch protection** on main branch
✅ **Require PR reviews** before merge
✅ **Use least-privilege** OCI credentials
✅ **Save output artifacts** for connection details
✅ **Monitor OCI console** regularly

---

## Related Documentation

- **Terraform Config:** `terraform/TERRAFORM-README.md`
- **Local Development:** `ansible/ANSIBLE-README.md`
- **Workflow File:** `.github/workflows/provision-infrastructure.yml`

---

## Implementation Notes

**Date:** October 2025  
**Approach:** Direct Terraform execution (industry standard)  
**Alternative:** Ansible orchestration available for local development  
**Status:** Production-ready ✅
