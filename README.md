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

### Registration of Resource Provider

the required resource provider "Microsoft.Communication" will in some cases not be registered when runnig terraform. To avoid errors, you may have to either manually register the provider via the Azure Portal or declare it in your condig.  

## Resources

| Name | Type |
|------|------|
| [random_string.main](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_email_communication_service.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/email_communication_service) | resource |
| [azapi_resource.domain](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.communication_services](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_api_connection.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_connection) | resource |
| [azurerm_logic_app_workflow.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_workflow) | resource |
| [azurerm_logic_app_trigger_recurrence.recurrence](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_recurrence) | resource |
| [azurerm_logic_app_action_custom.initialize_appid](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_displayname](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_passwordcredential](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_keycredential](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_styles](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_html](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_emailneeded](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_daystilexpiration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.initialize_nextlink](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.until](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.close_html_tags](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |
| [azurerm_logic_app_action_custom.condition_emailneeded](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_custom) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | "Short name of the environment. This is used in the naming convention of resource creation. If resource names are overwritten, this environment variable is not used for that resource" | `string` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription_id](#input\subscription_id) | Subscription id used when referencing to the API-Connection in the Logic App Workflow | `string` | n/a | yes |
| <a name="input_resource_location"></a> [resource\_location](#input\_resource\_location) | The location of Resource Group and Logic App | `string` | `n/a` | yes |
| <a name="input_data_location"></a> [data\_location](#input\_data\_location) | The location where the Communication service store its data at rest | `string` | `n/a` | yes |
| <a name="input_email_recipients"></a> [email\_recipients](#input\_email\_recipients) | List of email recipients | `list(string)` | `n/a` | yes |
| <a name="resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the Resource Group | `string` | `""` | no |
| <a name="email_communication_service_name"></a> [email\_communications\_service\_name](#input\_email\_communications\_service\_name) | The name of the Email Communication Service | `string` | `""` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The Resource Name of the domain | `string` | `AzureManagedDomain` | no |
| <a name="input_communication_services_name"></a> [communication\_services\_name](#input\_communication\_services\_name) | The name of the communication service | `string` | `""` | no |
| <a name="input_api_connection_name"></a> [api\_connection\_name](#input\_api\_connection\_name) | The name of the mail api-connection | `string` | `acsemail` | no |
| <a name="input_api_connection_display_name"></a> [api\_connection\_display\_name](#input\_api\_connection\_display\_name) | The display name of the mail api-connection | `string` | `Azure Communication Email` | no |
| <a name="input_logic_app_workflow_name"></a> [logic\_app\_workflow\_name](#input\_logic\_app\_workflow\_name) | The name of the Logic App Workflow | `string` | `""` | no |
| <a name="input_communication_services_location"></a> [communication\_services\_location](#input\_communication\_services\_location) | The geo-location where the communication services lives | `string` | `global` | no |
| <a name="input_logic_app_trigger_recurrence_frequency"></a> [logic\_app\_trigger\_recurrence\_frequency](#input\_logic\_app\_trigger\_recurrence\_frequency) | The frequency of the Logic App trigger | `string` | `Day` | no |
| <a name="input_logic_app_trigger_recurrence_interval"></a> [logic\_app\_trigger\_recurrence\_interval](#input\_logic\_app\_trigger\_recurrence\_interval) | The interval of the Logic App trigger | `number` | `4` | no |
| <a name="input_logic_app_trigger_get_future_time_interval"></a> [logic\_app\_trigger\_get\_future\_time\_interval](#input\_logic\_app\_trigger\_get\_future\_time\_interval) | The limit interval of credentials being alerted | `number` | `1` | no |
| <a name="input_logic_app_trigger_get_future_time_time_unit"></a> [logic\_app\_trigger\_get\_future\_time\_time\_unit](#input\_logic\_app\_trigger\_get\_future\_time\_time\_unit) | The limit unit of credentials being alerted | `string` | `Month` | no |
| <a name="input_email_subject"></a> [email\_subject](#input\_email\_subject) | The subject of the email being sent | `string` | `List of Secrets and Certificates near expiration` | no |

## Note

Inspired by [Use Azure Logic Apps to Notify of Pending AAD Application Client Secrets and Certificate Expirations](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/use-azure-logic-apps-to-notify-of-pending-aad-application-client/ba-p/3014603)  
