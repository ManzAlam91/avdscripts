<#
.Description
This script should be executed as an "Azure PowerShell" Pipeline Task that is configured to run before the "deploy-session-hosts.json" template is deployed.
Azure Pipeline variables are exposed as environment variables and can be retrieved using the "Env" PowerShell drive: $Env:VariableName.
To modify the value of an Azure Pipeline variable, use the "task.setvariable" logging command:
    Write-Host "##vso[task.setvariable variable=VariableName;]VariableValue"

The script performs the following operations:

1.	Creates a new Host Pool Registration Token
2.	Retrieves details about two resources created by the AVD Landing Zone deployment: AVD Workload Key Vault and FSLogix Storage Account.
3.	Populates the Pipeline Variables "avdKeyVaultName" and "fslogixStorageAccountName" with the above data

#>

$locationAcronyms = @{
    "canadacentral" = "cac"
    "canadaeast" =  "cae"
}


# Trust the PowerShell Gallery repository 
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Obtain the list of installed PowerShell modules
$InstalledModules = Get-Module -ListAvailable | ForEach-Object {$_.Name}

# Install the required Az Modules, if they are not present
"Az.DesktopVirtualization", "Az.KeyVault", "Az.Storage" | ForEach-Object `
    {
        if ($InstalledModules -notcontains $_) {

            Install-Module -Name $_ -Repository PSGallery -SkipPublisherCheck -AcceptLicense -AllowClobber -Force -Confirm:$False
        
        }
    }

#
# 1. Create a new Host Pool Registration Token
#

# Retrieve the Host Pool
$avdHostPool = Get-AzWvdHostPool -Name $Env:avdHostPoolCustomName -ResourceGroupName $Env:avdServiceObjectsRgCustomName -ErrorAction Stop

# Verify that the Host Pool has been successfully found
if (-not $avdHostPool) {

    Write-Error "Unable to find Host Pool $($Env:avdHostPoolCustomName) in Resouce Group $($Env:avdServiceObjectsRgCustomName)"

}

# Create a host pool registration token that is valid for 27 days
New-AzWvdRegistrationInfo -ResourceGroupName $Env:avdServiceObjectsRgCustomName -HostPoolName $Env:avdHostPoolCustomName -ExpirationTime (Get-Date).AddDays(27) -ErrorAction Stop

#
# 2. Retrieve and Populate AVD Workload Key Vault Name
#

# The name prefix of the AVD Workload Key Vault.
# Example: kv-avd-cac-avd1
$avdKeyVaultNamePrefix = ($Env:avdWrklKvPrefixCustomName).ToLower() + "-" + $locationAcronyms[$Env:avdSessionHostLocation] + "-" + ($Env:deploymentPrefix).ToLower()

# The key vault name is generated by appending a random 6-character string to the key vault name prefix.
# Example: kv-avd-cac-avd1-hvshyd
# Retrieve key vaults - in the Service objects resoure group - with a matching name
$avdkeyVault = Get-AzKeyVault -ResourceGroupName $Env:avdServiceObjectsRgCustomName -ErrorAction Stop | Where-Object VaultName -match $avdKeyVaultNamePrefix | Select-Object -First 1

# Verify that the Key Vault has been successfully found
if (-not $avdkeyVault) {

    Write-Error "Unable to find Key Vault with name prefix $avdKeyVaultNamePrefix in Resouce Group $($Env:avdServiceObjectsRgCustomName)"

}

# Set the Pipeline Variable "avdKeyVaultName"
Write-Host "##vso[task.setvariable variable=avdKeyVaultName;]$($avdKeyVault.VaultName)"

#
# 3. Retrieve and Populate FSLogix Storage Account Name
#

# Name prefix of the FSLogix Storage Account
# Example: stavdfslavd1
$fslogixStorageAccountNamePrefix = ($Env:storageAccountPrefixCustomName).ToLower() + "fsl" + ($Env:deploymentPrefix).ToLower()

# The storage accout name is generated by appending a random 6-character string to the storage account name prefix
# Retrieve storage accounts - in the storage objects resoure group - with a matching name
$fslogixStorageAccount = Get-AzStorageAccount -ResourceGroupName $Env:avdStorageObjectsRgCustomName -ErrorAction Stop | Where-Object StorageAccountName -match $fslogixStorageAccountNamePrefix | Select-Object -First 1

# Verify that the Storage Account has been successfully found
if (-not $fslogixStorageAccount) {

    Write-Error "Unable to find Storage Account with name prefix $fslogixStorageAccountNamePrefix in Resouce Group $($Env:avdStorageObjectsRgCustomName)"

}

# Set the Pipeline Variable "fslogixStorageAccountName"
Write-Host "##vso[task.setvariable variable=fslogixStorageAccountName;]$($fslogixStorageAccount.StorageAccountName)"
