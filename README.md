# Azure DevOps Repository Decommission Script

A PowerShell script that automates the process of identifying, renaming, and disabling Azure DevOps repositories that are marked for decommissioning.

## Overview

This script uses the Azure DevOps REST API to:

1. **Identify** all repositories whose names end with "DECOMMISSIONED"
2. **Rename** them with a "ZZ" prefix for easy sorting and identification
3. **Disable** the repositories to prevent further access

## Features

- ✅ **Safe Operations**: Includes WhatIf mode for testing without making changes
- ✅ **Smart Detection**: Only processes repositories ending with "DECOMMISSIONED"
- ✅ **Idempotent**: Safely handles repositories that are already renamed or disabled
- ✅ **Comprehensive Logging**: Detailed progress reporting and error handling
- ✅ **Efficient Processing**: Skips unnecessary operations on already-processed repositories

## Prerequisites

- **PowerShell 5.1** or later
- **Azure DevOps Personal Access Token** with appropriate permissions
- **Network access** to Azure DevOps (dev.azure.com)

### Required Permissions

Your Personal Access Token must have the following permissions:

- **Code (Read & Write)**: Required to read repository information and update repository properties

## Installation

1. Download the `DecommissionRepos.ps1` script
2. Place it in your desired directory
3. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Syntax

```powershell
.\DecommissionRepos.ps1 -Organization <OrgName> -Project <ProjectName> -PersonalAccessToken <PAT> [-WhatIf]
```

### Parameters

| Parameter             | Required | Description                                     |
| --------------------- | -------- | ----------------------------------------------- |
| `Organization`        | Yes      | The Azure DevOps organization name              |
| `Project`             | Yes      | The Azure DevOps project name                   |
| `PersonalAccessToken` | Yes      | Personal Access Token for authentication        |
| `WhatIf`              | No       | Shows what would be done without making changes |

### Examples

#### 1. Test Run (Recommended First Step)

```powershell
.\DecommissionRepos.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "your_pat_here" -WhatIf
```

#### 2. Actual Execution

```powershell
.\DecommissionRepos.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "your_pat_here"
```

#### 3. Using Variables for Convenience

```powershell
$org = "myorg"
$project = "myproject"
$pat = "your_pat_here"

# Test first
.\DecommissionRepos.ps1 -Organization $org -Project $project -PersonalAccessToken $pat -WhatIf

# Then execute
.\DecommissionRepos.ps1 -Organization $org -Project $project -PersonalAccessToken $pat
```

## How It Works

### Repository Selection

The script identifies repositories using this criteria:

- Repository name ends with "DECOMMISSIONED" (case-insensitive)
- Examples: `old-app-DECOMMISSIONED`, `legacy-service-decommissioned`

### Processing Logic

For each identified repository, the script:

1. **Checks current state** (enabled/disabled, current name)
2. **Renames repository** (if not already prefixed with "ZZ")
   - `old-app-DECOMMISSIONED` → `ZZold-app-DECOMMISSIONED`
3. **Disables repository** (if not already disabled)

### Smart Skip Logic

The script intelligently skips unnecessary operations:

- ✅ **Skip rename** if repository already starts with "ZZ"
- ✅ **Skip disable** if repository is already disabled
- ✅ **Skip entirely** if both conditions are met

## Sample Output

```
Starting Azure DevOps repository decommission process...
Organization: myorg
Project: myproject
WhatIf Mode: False

Fetching all repositories...
Found 5 total repositories
Found 2 repositories ending with 'DECOMMISSIONED':
  - old-service-DECOMMISSIONED
  - ZZlegacy-app-DECOMMISSIONED

Processing repository: old-service-DECOMMISSIONED
  Current status: Enabled
  Renaming repository...
  ✓ Successfully renamed from 'old-service-DECOMMISSIONED' to 'ZZold-service-DECOMMISSIONED'
  Disabling repository...
  ✓ Successfully disabled repository

Processing repository: ZZlegacy-app-DECOMMISSIONED
  Current status: Disabled
  → Repository name already has ZZ prefix, skipping rename
  → Repository already disabled, skipping disable

Process completed!
Successfully processed: 2 repositories
Failed to process: 0 repositories
```

## Security Considerations

### Personal Access Token

- **Store securely**: Never commit PAT to version control
- **Use environment variables** for automation scenarios:
  ```powershell
  $pat = $env:AZURE_DEVOPS_PAT
  .\DecommissionRepos.ps1 -Organization $org -Project $project -PersonalAccessToken $pat
  ```
- **Limit scope**: Only grant necessary permissions (Code Read & Write)
- **Set expiration**: Use tokens with reasonable expiration dates

### Script Execution

- **Test first**: Always run with `-WhatIf` before actual execution
- **Review output**: Verify the list of repositories to be processed
- **Run incrementally**: Process small batches for large organizations

## Troubleshooting

### Common Issues

#### Authentication Failed

```
Error: Response status code does not indicate success: 401 (Unauthorized)
```

**Solution**: Verify your Personal Access Token has the correct permissions and hasn't expired.

#### Repository Not Found

```
Error: Response status code does not indicate success: 404 (Not Found)
```

**Solution**: Verify the organization and project names are correct.

#### Permission Denied

```
Error: Response status code does not indicate success: 403 (Forbidden)
```

**Solution**: Ensure your PAT has "Code (Read & Write)" permissions.

### Getting Help

1. **Run with WhatIf**: Use `-WhatIf` to see what the script would do
2. **Check permissions**: Verify PAT permissions in Azure DevOps
3. **Validate parameters**: Confirm organization and project names
4. **Review output**: The script provides detailed error messages

## API Reference

This script uses the Azure DevOps REST API:

- **API Version**: 7.1
- **Endpoint**: `GET/PATCH /git/repositories`
- **Documentation**: [Azure DevOps REST API - Git Repositories](https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories)
