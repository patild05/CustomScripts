# Obviously, replace the following with your own values
$subscriptionId = "bxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$tenantId = "0xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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
