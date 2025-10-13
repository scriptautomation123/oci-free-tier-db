# GitHub Actions Quick Start Guide

## 🚀 5-Minute Setup

### Step 1: Configure Secrets (One-Time Setup)

Navigate to your repository: **Settings → Secrets and variables → Actions**

Add these secrets:

```
OCI_COMPARTMENT_OCID = ocid1.compartment.oc1..aaaaaaaa...
DB_ADMIN_PASSWORD = [Your secure password - optional]
```

### Step 2: Create GitHub Environments (One-Time Setup)

Navigate to: **Settings → Environments**

Create two environments:

1. **production**
   - Add required reviewers (yourself or team members)
   - Optional: Set wait timer (e.g., 5 minutes)

2. **destroy**
   - Add required reviewers
   - **Recommended**: Require 2+ reviewers for safety

### Step 3: Run Your First Deployment

1. Go to **Actions** tab
2. Click **"Provision OCI Infrastructure"** workflow
3. Click **"Run workflow"** button
4. Select:
   - Environment: `partition-test`
   - Action: `plan`
5. Click **"Run workflow"**
6. ✅ Review the plan output

### Step 4: Deploy Infrastructure (When Ready)

1. Go to **Actions** tab
2. Click **"Provision OCI Infrastructure"** workflow
3. Click **"Run workflow"** button
4. Select:
   - Environment: `partition-test`
   - Action: `apply` ⚠️
5. Click **"Run workflow"**
6. **Approve** the deployment when prompted
7. ✅ Infrastructure deployed!

## 📋 Common Tasks

### Check Deployment Status

```
Actions tab → Select latest workflow run → View job logs
```

### Download Terraform Outputs

```
Actions tab → Select workflow run → Scroll to "Artifacts" → Download "terraform-outputs"
```

### Destroy Infrastructure

⚠️ **WARNING**: This permanently deletes all resources!

```
1. Actions → "Provision OCI Infrastructure"
2. Run workflow → Action: "destroy"
3. Approve destruction (requires environment approval)
```

## 🔒 Security Checklist

- [ ] Secrets configured in GitHub (never commit secrets!)
- [ ] Environments created with approval requirements
- [ ] Branch protection enabled on `main` branch (recommended)
- [ ] PR reviews required before merge (recommended)
- [ ] OCI credentials follow least-privilege principle

## 📊 What Gets Created?

All resources use **Always Free tier** (zero cost):

- ✅ Oracle Autonomous Database (1 OCPU, 20GB)
- ✅ Object Storage Bucket (20GB limit)
- ✅ VCN and networking resources
- 💰 **Cost: $0.00/month permanently**

## 🆘 Troubleshooting

### "Workflow not found"
- Make sure you're on the right branch
- Check that `.github/workflows/provision-infrastructure.yml` exists

### "Secret not found"
- Verify secrets are configured in Settings → Secrets
- Check secret names match exactly (case-sensitive)

### "Environment not found"
- Create environments in Settings → Environments
- Names must be: `production` and `destroy`

### "Terraform plan failed"
- Check OCI credentials are valid
- Verify compartment OCID is correct
- Review workflow logs for specific errors

## 📚 Full Documentation

For complete details, see:

- **[Full Guide](.github/GITHUB_ACTIONS_GUIDE.md)** - Comprehensive documentation
- **[Terraform Details](../terraform/TERRAFORM-README.md)** - Infrastructure details
- **[Main README](../README.md)** - Project overview

## 💡 Pro Tips

1. **Start with plan**: Always run `plan` action first to see what will change
2. **Review logs**: Check workflow logs even for successful runs
3. **Save outputs**: Download Terraform output artifacts for connection details
4. **Use PR reviews**: Enable branch protection and require reviews
5. **Monitor costs**: Check OCI console regularly (should always be $0.00)

---

**Setup Time**: ~5 minutes  
**First Deployment**: ~10-15 minutes  
**Cost**: $0.00 (Always Free tier)
