# 🛠️ DevOps Toolkit Reference Guide

A modular set of 40 scoped entries for secure, scalable, and auditable Azure DevOps automation.

---

## 🔧 Identity & Access Control

### 1. Build Agent Permissions via ACL APIs

```powershell
Add-AzDevOpsAccessControlEntry -Token $token -Descriptor $descriptor -AllowPermissions $permissions
```

- Automate build agent access to pipelines and environments  
- Use descriptor lookup and retry logic for propagation delays

---

### 2. Identity Descriptor Formats & Troubleshooting

```powershell
Get-AzDevOpsDescriptor -PrincipalName "user@contoso.com"
```

- Resolve identity formats for ACL and RBAC  
- Cache descriptors for reuse across environments

---

### 3. Service Principal Creation & Role Assignment

```powershell
New-AzADServicePrincipal | New-AzRoleAssignment -Role "Contributor" -Scope $scope
```

- Automate secure access for pipelines  
- Log SP metadata and role scope for audit

---

### 4. Federated Identity Across Tenants

```powershell
New-AzADServicePrincipalFederatedIdentityCredential -ServicePrincipalId $sp.Id `
  -Name "cross-tenant-gha" `
  -Issuer "https://token.actions.githubusercontent.com" `
  -Subject "repo:{org}/{repo}:ref:refs/heads/main" `
  -Audience "api://AzureADTokenExchange"
```

- Enable secretless auth for GitHub Actions  
- Scope subject to repo and branch for least privilege

---

### 5. Centralized Role Management

```powershell
function Grant-Role {
  param ($PrincipalId, $RoleName, $Scope)
  New-AzRoleAssignment -ObjectId $PrincipalId -RoleDefinitionName $RoleName -Scope $Scope
}
```

- Reuse role assignment logic across environments  
- Log each assignment with timestamp and scope

---

### 6. Secure Secret Handling

```yaml
variables:
  - group: SecureSecrets
```

- Reference secrets from variable groups  
- Use Key Vault-backed groups for rotation and audit

---

### 7. Audit-Friendly Automation Workflows

```powershell
$logEntry = @{
  Timestamp     = (Get-Date).ToString("s")
  PrincipalId   = $sp.Id
  RoleAssigned  = "Contributor"
  Scope         = $scope
} | ConvertTo-Json

Add-Content -Path "./logs/role-assignments.json" -Value $logEntry
```

- Log automation actions for traceability  
- Use structured formats like JSON for parsing

---

## 🚀 Pipeline Architecture & Execution

### 8. Templating Azure Pipelines for Reuse

```yaml
parameters:
  - name: environment
    type: string

jobs:
  - job: Deploy
    steps:
      - script: pwsh ./scripts/deploy.ps1 -Env ${{ parameters.environment }}
```

- Reduce duplication and enforce consistency  
- Document template usage in repo README

---

### 9. Conditional Deployment Logic

```yaml
condition: and(succeeded(), eq(variables['DeployEnabled'], 'true'))
```

- Gate stages based on flags or outcomes  
- Use pipeline variables to toggle behavior

---

### 10. Environment-Specific Logic

```yaml
variables:
  - name: deployEnv
    value: 'prod'

steps:
  - script: pwsh ./scripts/deploy.ps1 -Env $(deployEnv)
```

- Parameterize logic by environment  
- Use variable groups for shared values

---

### 11. Cross-Subscription Deployments

```powershell
Connect-AzAccount -Subscription $targetSubId
```

- Deploy resources across multiple subscriptions  
- Use service principal with multi-sub access

---

### 12. Promotion Workflows

```yaml
- stage: PromoteToProd
  dependsOn: PostDeployTests
  condition: succeeded()
```

- Promote only validated builds  
- Use approval gates for sensitive environments

---

### 13. Deployment Approvals

```yaml
environments:
  - name: prod
    approval:
      reviewers:
        - id: user1@contoso.com
```

- Require manual approval before production deploy  
- Use tags and timeouts to customize flow

---

### 14. Release Tagging

```yaml
steps:
  - script: echo "##vso[build.addbuildtag]release-$(Build.BuildNumber)"
```

- Label pipeline runs for traceability  
- Use semantic or date-based tags

---

### 15. Artifact Versioning

```yaml
artifactName: 'FunctionApp_$(artifactVersion)'
```

- Track and reuse specific build outputs  
- Link version to pipeline run and release notes

---

### 16. Cross-Environment Promotion Tracking

```yaml
variables:
  - name: promotedFrom
    value: 'dev'
```

- Trace deployment lineage across stages  
- Log promotion metadata for audit

---

## 🧪 Deployment Validation & Recovery

### 17. Deployment Traceability Across Stages

```yaml
echo "##vso[task.setvariable variable=infraDeploymentId]INFRA-$(Build.BuildId)"
```

- Link infra and app stages  
- Use shared variables for traceability

---

### 18. Post-Deployment Testing

```yaml
steps:
  - script: pwsh ./tests/run-tests.ps1 -Env 'prod'
```

- Validate app behavior after deploy  
- Publish test results as artifacts

---

### 19. Environment Health Checks

```powershell
$functionApp = Get-AzWebApp -ResourceGroup $rgName -Name $functionAppName
```

- Confirm resource readiness  
- Check dependencies like storage and identity

---

### 20. Deployment Validation Before Promotion

```powershell
$response = Invoke-WebRequest -Uri "https://$functionAppName.azurewebsites.net/api/health"
```

- Gate promotion on health checks  
- Exit with error if validation fails

---

### 21. Failure Recovery Strategies

```yaml
condition: failed()
```

- Trigger recovery logic on failure  
- Log recovery actions and notify stakeholders

---

### 22. Rollback Strategies

```powershell
Publish-AzWebApp -ArchivePath "./backups/FunctionApp_20250801.zip"
```

- Restore previous deployment  
- Archive packages before each release

---

## 📦 Artifact & Release Management

### 23. Artifact Staging & Publishing

```yaml
pathToPublish: '$(Build.ArtifactStagingDirectory)'
```

- Stage outputs for downstream use  
- Use consistent artifact names

---

### 24. Versioning Strategy

```yaml
variables:
  artifactVersion: 'v1.2.3'
```

- Identify builds uniquely  
- Automate version bumping via Git tags

---

### 25. Linking Artifacts to Pipeline Runs

```yaml
artifactName: 'FunctionApp_$(Build.BuildId)'
```

- Correlate artifacts with build metadata  
- Include version in release notes

---

### 26. Tagging Pipeline Runs

```yaml
echo "##vso[build.addbuildtag]stable"
```

- Mark key builds for visibility  
- Use tags to filter in UI

---

### 27. Release Documentation & Metadata Logging

```powershell
Add-Content -Path "./logs/releases.json" -Value $releaseMetadata
```

- Capture release context  
- Include deployment ID, timestamp, and notes

---

## 📊 Observability & Telemetry

### 28. Custom Telemetry Emission

```powershell
Send-CustomTelemetry -Properties $properties
```

- Push metrics to Azure Monitor  
- Standardize fields across stages

---

### 29. Logging Role Assignments

```powershell
ConvertTo-Json $logEntry | Out-File "./logs/role-assignments.json"
```

- Track access changes  
- Include timestamp and scope

---

### 30. Logging Promotion Metadata

```powershell
echo "Promoted from $(promotedFrom) with deployment ID $(sourceDeploymentId)"
```

- Trace promotion lineage  
- Store in centralized log file

---

### 31. Publishing Test Results as Artifacts

```yaml
- task: PublishTestResults@2
```

- Surface validation outcomes  
- Use JUnit or TRX formats

---

### 32. Surfacing Health Check Results

```powershell
Write-Output "Function App status: $($functionApp.State)"
```

- Confirm environment readiness  
- Include in pipeline logs

---

### 33. Linking Logs to Deployment IDs

```powershell
$log = @{
  DeploymentId = $env:BUILD_BUILDID
  Timestamp    = (Get-Date).ToString("s")
} | ConvertTo-Json
```

- Correlate logs with pipeline runs  
- Use consistent metadata fields

---

## 🧱 Reusability & Modularity

### 34. Reusable PowerShell Modules

```powershell
Import-Module ./modules/DeployTools.psm1
```

- Centralize shared logic  
- Version and document modules

---

### 35. Parameterized Script Logic

```powershell
param (
  [string]$Environment,
  [string]$AppName
)
```

- Support flexible deployments  
- Validate inputs and default values

---

### 36. Shared Variable Maps

```yaml
variables:
  - name: appName
    value: 'MyFunctionApp'
```

- Define reusable values across stages  
- Use variable groups for consistency

---

### 37. Centralized Logging Modules

```powershell
function Write-Log {
  param ($Message)
  Add-Content -Path "./logs/deploy.log" -Value "$(Get-Date): $Message"
}
```

- Standardize logging across scripts  
- Include timestamps and context

---

### 38. Modular Deployment Templates

```yaml
- template: deploy-functionapp.yml
  parameters:
    environment: 'test'
```

- Break pipelines into reusable components  
- Pass parameters for flexibility

---

### 39. Scoped Environment Configurations

```yaml
variables:
  - name: configFile
    value: 'configs/test.json'
```

- Load environment-specific settings  
- Use config files for infra and app values

---

### 40. Update Workflows for Shared Components

```powershell
git pull origin main
Update-Module ./modules/DeployTools.psm1
```

- Keep shared logic up to date  
- Automate sync across projects
