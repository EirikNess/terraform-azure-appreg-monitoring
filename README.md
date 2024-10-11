# Monitor App Registration Secret and Certificate Expiry with Logic App  

## Information  

A terraform module that will deploy a logic app that will fetch all app registration in a tenant and send mail alerts with Azure Communication Service if there are expiring credentials. Default recurrence of this logic app is to run every 4 day, and secrets/certificates expiring within 30 days will be alerted. It does not send mail if no expiring secrets are retrieved

### Usage

### Example with default naming convention  

```terraform

data "azurerm_client_config" "current" {}

module "monitor_appreg" {
    environment = "contoso"
    subscription_id = data.azurerm_client_config.current.subscription_id
    resource_location = "norwayeast"
    data_location = "Norway"
    email_recipients = ["user1@contoso.com", "user2@contoso.com"]
}
```

### Example with custom naming convention

```terraform

data "azurerm_client_config" "current" {}

module "monitor_appreg" {
    environment = "contoso"
    subscription_id = data.azurerm_client_config.current.subscription_id
    resource_location = "West Europe"
    data_location = "Europe"
    resource_group_name "rg-monitorappreg"
    email_communication_service_name = "ecs-monitorappreg"
    domain_name = "Contoso"
    communication_services_name = "acs-monitorappreg"
    api_connection_name = "asc-sendmail"
    logic_app_workflow_name = "logic-monitorappreg"
    email_recipients = ["user1@contoso.com", "user2@contoso.com"]
}
```

### Example with custom scheduling

```terraform

data "azurerm_client_config" "current" {}

module "monitor_appreg" {
    environment = "contoso"
    subscription_id = data.azurerm_client_config.current.subscription_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    resource_location = "norwayeast"
    data_location = "Norway"
    logic_app_trigger_recurrence_frequency = "Week"
    logic_app_trigger_recurrence_interval = 2
    logic_app_trigger_get_future_time_time_unit = "Week"
    logic_app_trigger_get_future_time_interval = 5
    email_recipients = ["user1@contoso.com", "user2@contoso.com"]
}
```

### Assign role for Logic App

The logic app SystemAssigned managed identity needs Directory.Read.All and Application.Read.All permission to run the Graph Query. You can set the permission either using the output from the module, or for example using this script:

```powershell

# Connect to Microsoft Graph with the necessary scopes
Connect-MgGraph -Scopes 'Application.ReadWrite.All,AppRoleAssignment.ReadWrite.All'
 
# Retrieve the Microsoft Graph service principal
$graph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
 
# Retrieve the Application.Read.All permission
$applicationReadAll = $graph.AppRoles |
Where-Object { $_.Value -eq "Application.Read.All" -and $_.AllowedMemberTypes -contains "Application" } |
Select-Object -First 1
 
# Retrieve the Directory.Read.All permission
$directoryReadAll = $graph.AppRoles |
Where-Object { $_.Value -eq "Directory.Read.All" -and $_.AllowedMemberTypes -contains "Application" } |
Select-Object -First 1
 
# Retrieve the service principal of your managed identity
$msi = Get-MgServicePrincipal -Filter "Id eq '<logic-app-identity>'"
 
# Assign Application.Read.All to the managed identity
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $msi.Id `
    -AppRoleId $applicationReadAll.Id `
    -PrincipalId $msi.Id `
    -ResourceId $graph.Id
 
# Assign Directory.Read.All to the managed identity
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $msi.Id `
    -AppRoleId $directoryReadAll.Id `
    -PrincipalId $msi.Id `
    -ResourceId $graph.Id

```

## Note

Inspired by [Use Azure Logic Apps to Notify of Pending AAD Application Client Secrets and Certificate Expirations](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/use-azure-logic-apps-to-notify-of-pending-aad-application-client/ba-p/3014603)  
