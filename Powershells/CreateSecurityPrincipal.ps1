# Obviously, replace the following with your own values
$subscriptionId = "b6c72194-a2d4-49a2-9317-9f42d823cec6"
$tenantId = "033a7408-6de4-42db-920e-57ae321da0e5"
$password = ConvertTo-SecureString -String "Password@123" -AsPlainText -Force
Write-Output $password

# Login to your Azure Subscription
Login-AzureRMAccount
Set-AzureRMContext -SubscriptionId $subscriptionId -TenantId $tenantId

# Create an Octopus Deploy Application in Active Directory
Write-Output "Creating AAD application..."
$azureAdApplication = New-AzureRmADApplication -DisplayName "Dummy Deploy" -HomePage "http://dummyzero.com" -IdentifierUris "http://dummyzero.com" -Password $password
$azureAdApplication | Format-Table

# Create the Service Principal
Write-Output "Creating AAD service principal..."
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
$servicePrincipal | Format-Table

# Sleep, to Ensure the Service Principal is Actually Created
Write-Output "Sleeping for 10s to give the service principal a chance to finish creating..."
Start-Sleep -s 10
 
# Assign the Service Principal the Contributor Role to the Subscription.
# Roles can be Granted at the Resource Group Level if Desired.
Write-Output "Assigning the Contributor role to the service principal..."
New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $azureAdApplication.ApplicationId

# The Application ID (aka Client ID) will be Required When Creating the Account in Octopus Deploy
Write-Output "Client ID: $($azureAdApplication.ApplicationId)"