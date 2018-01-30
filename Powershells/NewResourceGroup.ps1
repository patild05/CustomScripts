[CmdletBinding()]
Param
(
    # Choose the Subscription Name
    [Parameter(Mandatory=$false)]
    [ValidateSet("TSE-Enterprise","PC-NL","PC-UK","DownSb","Sandbox","Visual Studio Enterprise")][String]$SubscriptionName = "Visual Studio Enterprise",
    # Choose the ResourceGroup location
    [Parameter(Mandatory=$false)]
    [ValidateSet("NE", "WE")][String]$ResourceGroupLocation = "WE",
    # Choose the RBAC Role name
    [Parameter(Mandatory=$false)]
    [String]$RBACRoleName = "Contributor",
    [Parameter(Mandatory=$false)]
    [String]$WRSIdTag = "231",
    [Parameter(Mandatory=$false)]
    [String]$ApplicationNameTag = "Dummy",
    [Parameter(Mandatory=$false)]
    [ValidateSet("DEV","TST","QA","PROD","SBX")][String]$EnvironmentTag = "Dev",
    [Parameter(Mandatory=$false)]
    [String]$WBSCodeTag = "12dfdf",
    [Parameter(Mandatory=$false)]
    [ValidateSet("Low","Medium","High")][String]$BIAScoreTag = "Low",
    [Parameter(Mandatory=$false)]
    [String]$ADGroup = "Group1",    
    [Parameter(Mandatory=$false)]
    [ValidatePattern("[\D\d]+[@][t][a][t][a][s][t][e][e][l][.][c][o][m]")][String]$ManagedByTag = "Dipak",
    [Parameter(Mandatory=$false)]
    [ValidatePattern("[\D\d]+[@][t][a][t][a][s][t][e][e][l][.][c][o][m]")][String]$UsedByTag= "Dick"
)

Write-Host "Logging in...";

try
{    
   $cred = Get-Credential -UserName 6f08a82b-50f0-472d-888f-70cc1cc925be -Message "Enter the credentials"
   Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 033a7408-6de4-42db-920e-57ae321da0e5

}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception    
}

# Stop the runbook if something fails
$ErrorActionPreference = "Stop"
# Select the Azure Subscription
Write-Output "INFO --- Switching to subscription $SubscriptionName"
$Subscription = Select-AzureRmSubscription -Subscription b6c72194-a2d4-49a2-9317-9f42d823cec6
# Check if location is valid
$AllowedRegions = 'NE','WE'

If ($ResourceGroupLocation -ilike 'NE') {
    $LongResourceGroupLocation = "North Europe"
    Write-Output "INFO --- Region is set to $ResourceGroupLocation, which is valid."
    Write-Output "Long Resource Group Location Name is $LongResourceGroupLocation"
}
ElseIf($ResourceGroupLocation -ilike 'WE'){
    $LongResourceGroupLocation = "West Europe"
    Write-Output "INFO --- Region is set to $ResourceGroupLocation, which is valid."
    Write-Output "Long Resource Group Location Name is $LongResourceGroupLocation"
}
Else {
    Write-Output "INFO --- Region $ResourceGroupLocation is not valid.Please choose one of the following:"
    Write-Output $AllowedRegions
    Write-Error –Message "Runbook has failed. Please check the output of the job."
}

# Create the resource group name, but need confirmation on Resource Group naming convention, for time being following is in place
$ResourceGroupName = $ApplicationNameTag + "-" + $EnvironmentTag + "-" +"RG"

Write-Output "Preparing.."


# Check if the AAD Group exists. If not, fail
$AADGroup = Get-AzureRmADGroup -SearchString $ResourceGroupName
If (($AADGroup).DisplayName -eq $Null) {
    Write-Output "ERROR --- Azure AD Group with name $ResourceGroupName doesn't exist."
    Write-Output "ERROR --- Please create the AAD Group first and add the Administrator user to it, before running this script again."
    Write-Error –Message "Runbook has failed. Please check the output of the job."
}
Else {
    Write-Output "INFO --- Azure AD Group $ResourceGroupName exists."
}


#Check if Resource Group exists. If yes, fail.
$ResourceGroupCheck = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
If ($ResourceGroupCheck -eq $Null) {
    Write-Output "INFO --- Check succeeded. Resource Group $ResourceGroupName doesn't exist."
}
Else {
    Write-Output "ERROR --- Resource group $ResourceGroupName already exists. Exiting script."
    Write-Output "ERROR --- Please check if the Resource Group exists."
    Write-Error –Message "Runbook has failed. Please check the output of the job."
}


# Create the Resource Group with the location and tags.
$ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LongResourceGroupLocation
# Create the resource group for the user
Write-Output "INFO --- Creating resource group with name $ResourceGroupName in $LongResourceGroupLocation $($ResourceGroup.ProvisioningState)"

# Assign the Azure Role to the Resource Group
Write-Output "INFO --- Assigning the Azure role to the Resource Group"
New-AzureRmRoleAssignment -ResourceGroupName $ResourceGroupName -RoleDefinitionName $RBACRoleName -ObjectId $AADGroup.Id.Guid -ErrorAction Continue

# Add multiple tags to the Resource Group
$Tags = (Get-AzureRmResourceGroup -Name $ResourceGroupName).Tags
Write-Output $Tags
Write-Output "INFO --- Assigning the tag values to the Resource Group"

$Tags += @{WRSID = "$WRSIdTag"}
$Tags += @{ApplicationName = "$ApplicationNameTag"}
$Tags += @{Environment="$EnvironmentTag"}
$Tags += @{BillTo = "$WBSCodeTag"}
$Tags += @{Administrator = "$ManagedByTag"}
$Tags += @{UsedBy = "$UsedByTag"}
$Tags += @{BIAScore = "$BIAScoreTag"}
$Tags += @{Region = "$ResourceGroupLocation"}

If($SubscriptionName -eq 'Sandbox' -or $SubscriptionName -eq 'visual studio EnterPrise'){
$Tags += @{ExpiresOn  = (Get-Date).AddYears(3)}
}

Write-Output "INFO --- Creating the following tags:"
Write-Output $Tags

# Write all the tags back to the Resource Groups
$Null = Set-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags

# Set ARM policies for RG

#Geo policy - restricting locations to West Europe and North Europe
$definition = '{"if": {"not": {"field": "location","in": [ "northeurope", "westeurope"]}},"then": {"effect": "deny"}}'
$policydef = New-AzureRmPolicyDefinition -Name GeoPolicy -Description 'Only North Europe and West Europe allowed' -Policy $definition
 
# Assign the policy
New-AzureRmPolicyAssignment -Name GeoPolicy -PolicyDefinition $policydef -Scope $ResourceGroup.ResourceId


#IP address policy -- restricting Public IP assignment policy
$definition = '{"if":{"anyOf":[{"source":"action","like":"Microsoft.Network/publicIPAddresses/*"}]},"then":{"effect":"deny"}}'
$policydef = New-AzureRmPolicyDefinition -Name NoPubIPPolicyDefinition -Description 'No public IP addresses allowed' -Policy $definition
 
# Assign the policy
New-AzureRmPolicyAssignment -Name NoPublicIPPolicyAssignment -PolicyDefinition $policydef -Scope $ResourceGroup.ResourceId


#VMSKU policy -- for Dev environment or Sandbox subscription restrict user to Basic VMs


# Output all the usefull information
Write-Output "--------------- Details ---------------"
Write-Output "Resource Group Name: $ResourceGroupName"
Write-Output "Resource Group Location: $ResourceGroupLocation"
Write-Output "Virtual Machine Naming Convention: $("$NamingConvention" + "*"), e.g. $("$NamingConvention" + "SQL001") (Max. 15 characters)"
Write-Output "Resource Group User: $ManagedByTag"
Write-Output "User Role: $RBACRoleName"
Write-Output "Subscription Name: $SubscriptionName"
Write-Output "Resource Group Tags:"
Write-Output $Tags
Write-Output "--------------- Details ---------------"
# Ending script
Write-Output "INFO --- Ending New-ResourceGroup script at $(Get-Date -Format "dd-MM-yyyy HH:mm")"
