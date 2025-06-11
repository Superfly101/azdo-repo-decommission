#Requires -Version 5.1

<#
.SYNOPSIS
    Identifies, disables, and renames Azure DevOps repositories ending with "DECOMMISSIONED"

.DESCRIPTION
    This script uses the Azure DevOps REST API to:
    1. Find all repositories whose names end with "DECOMMISSIONED"
    2. Disable these repositories
    3. Rename them to start with "ZZ" prefix

.PARAMETER Organization
    The Azure DevOps organization name

.PARAMETER Project
    The Azure DevOps project name

.PARAMETER PersonalAccessToken
    Personal Access Token for authentication

.PARAMETER WhatIf
    Shows what would be done without making changes

.EXAMPLE
    .\DecommissionRepos.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "pat123" -WhatIf

.EXAMPLE
    .\DecommissionRepos.ps1 -Organization "myorg" -Project "myproject" -PersonalAccessToken "pat123"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    
    [Parameter(Mandatory = $true)]
    [string]$Project,
    
    [Parameter(Mandatory = $true)]
    [string]$PersonalAccessToken,
    
    [switch]$WhatIf
)

# Function to create authorization header
function Get-AuthHeader {
    param([string]$Token)
    
    $encodedToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Token"))
    return @{
        'Authorization' = "Basic $encodedToken"
        'Content-Type'  = 'application/json'
    }
}

# Function to make REST API calls with error handling
function Invoke-AzDoRestApi {
    param(
        [string]$Uri,
        [string]$Method = 'GET',
        [hashtable]$Headers,
        [string]$Body = $null
    )
    
    try {
        $params = @{
            Uri     = $Uri
            Method  = $Method
            Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        return Invoke-RestMethod @params
    }
    catch {
        $errorMessage = $_.Exception.Message
        $statusCode = $null
        $responseBody = $null
        
        # Try to extract more detailed error information
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            try {
                $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $responseBody = $streamReader.ReadToEnd()
                $streamReader.Close()
            }
            catch {
                # If we can't read the response body, continue with basic error
            }
        }
        
        # Create comprehensive error message
        $fullErrorMessage = "API call failed: $errorMessage"
        if ($statusCode) {
            $fullErrorMessage += " (Status: $statusCode)"
        }
        if ($responseBody) {
            $fullErrorMessage += " - Response: $responseBody"
        }
        $fullErrorMessage += " - URI: $Uri"
        
        throw $fullErrorMessage
    }
}

# Main script execution
try {
    Write-Host "Starting Azure DevOps repository decommission process..." -ForegroundColor Green
    Write-Host "Organization: $Organization" -ForegroundColor Cyan
    Write-Host "Project: $Project" -ForegroundColor Cyan
    Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Cyan
    Write-Host ""

    # Create authentication header
    $headers = Get-AuthHeader -Token $PersonalAccessToken
    
    # Base API URL
    $baseUrl = "https://dev.azure.com/$Organization/$Project/_apis"
    
    # Step 1: Get all repositories
    Write-Host "Fetching all repositories..." -ForegroundColor Yellow
    $reposUri = "$baseUrl/git/repositories?api-version=7.0"
    $response = Invoke-AzDoRestApi -Uri $reposUri -Headers $headers
    
    $allRepos = $response.value
    Write-Host "Found $($allRepos.Count) total repositories" -ForegroundColor Green
    
    # Step 2: Filter repositories ending with "DECOMMISSIONED"
    $decommissionedRepos = $allRepos | Where-Object { $_.name -like "*DECOMMISSIONED" }
    
    if ($decommissionedRepos.Count -eq 0) {
        Write-Host "No repositories found ending with 'DECOMMISSIONED'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Found $($decommissionedRepos.Count) repositories ending with 'DECOMMISSIONED':" -ForegroundColor Green
    foreach ($repo in $decommissionedRepos) {
        Write-Host "  - $($repo.name)" -ForegroundColor White
    }
    Write-Host ""
    
    # Step 3: Process each decommissioned repository
    $successCount = 0
    $errorCount = 0
    
    foreach ($repo in $decommissionedRepos) {
        $repoName = $repo.name
        $repoId = $repo.id
        $isAlreadyDisabled = $repo.isDisabled
        
        Write-Host "Processing repository: $repoName" -ForegroundColor Cyan
        Write-Host "  Current status: $(if ($isAlreadyDisabled) { 'Disabled' } else { 'Enabled' })" -ForegroundColor Gray
        
        try {
            # Check if repo name already starts with "ZZ"
            $newName = if ($repoName.StartsWith("ZZ")) {
                $repoName
            }
            else {
                "ZZ$repoName"
            }
            
            # Prepare update payload for renaming (first operation)
            $renamePayload = @{
                name = $newName
            } | ConvertTo-Json
            
            # Prepare update payload for disabling (second operation)
            $disablePayload = @{
                isDisabled = $true
            } | ConvertTo-Json
            
            if ($WhatIf) {
                if ($repoName -ne $newName) {
                    Write-Host "  [WHATIF] Would rename from '$repoName' to '$newName'" -ForegroundColor Magenta
                }
                if (-not $isAlreadyDisabled) {
                    Write-Host "  [WHATIF] Would disable repository" -ForegroundColor Magenta
                }
                else {
                    Write-Host "  [WHATIF] Repository already disabled, no action needed" -ForegroundColor Magenta
                }
            }
            else {
                $updateUri = "$baseUrl/git/repositories/$($repoId)?api-version=7.1"
                
                # Step 4a: First rename the repository (only if name is different)
                if ($repoName -ne $newName) {
                    Write-Host "  Renaming repository..." -ForegroundColor Yellow
                    $renameResponse = Invoke-AzDoRestApi -Uri $updateUri -Method 'PATCH' -Headers $headers -Body $renamePayload
                    Write-Host "  ✓ Successfully renamed from '$repoName' to '$newName'" -ForegroundColor Green
                }
                else {
                    Write-Host "  → Repository name already has ZZ prefix, skipping rename" -ForegroundColor Gray
                }
                
                # Step 4b: Then disable the repository (only if not already disabled)
                if (-not $isAlreadyDisabled) {
                    Write-Host "  Disabling repository..." -ForegroundColor Yellow
                    $disableResponse = Invoke-AzDoRestApi -Uri $updateUri -Method 'PATCH' -Headers $headers -Body $disablePayload
                    Write-Host "  ✓ Successfully disabled repository" -ForegroundColor Green
                }
                else {
                    Write-Host "  → Repository already disabled, skipping disable" -ForegroundColor Gray
                }
                
                $successCount++
            }
        }
        catch {
            Write-Error "  ✗ Failed to process repository '$repoName': $($_.Exception.Message)"
            $errorCount++
        }
        
        Write-Host ""
    }
    
    # Summary
    Write-Host "Process completed!" -ForegroundColor Green
    if (-not $WhatIf) {
        Write-Host "Successfully processed: $successCount repositories" -ForegroundColor Green
        if ($errorCount -gt 0) {
            Write-Host "Failed to process: $errorCount repositories" -ForegroundColor Red
        }
    }
    else {
        Write-Host "WhatIf mode - no changes were made" -ForegroundColor Yellow
        Write-Host "Would have processed: $($decommissionedRepos.Count) repositories" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}