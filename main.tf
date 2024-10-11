resource "random_string" "main" {
  length  = 4
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name == "" ? "rg-appregmonitoring${var.environment}" : var.resource_group_name
  location = var.resource_location
}

resource "azurerm_email_communication_service" "main" {
  name                = var.email_communication_service_name == "" ? "ecs-appregmonitoring${var.environment}" : var.email_communication_service_name
  resource_group_name = azurerm_resource_group.main.name
  data_location       = var.data_location
}

resource "azapi_resource" "domain" {
  type      = "Microsoft.Communication/emailServices/domains@2023-03-31"
  name      = var.domain_name
  parent_id = azurerm_email_communication_service.main.id
  location  = var.communication_services_location

  body = jsonencode({
    properties = {
      domainManagement       = "AzureManaged"
      userEngagementTracking = "Disabled"
    }
  })
  response_export_values = ["*"]
}

resource "azapi_resource" "communication_services" {
  type      = "Microsoft.Communication/CommunicationServices@2023-03-31"
  name      = var.communication_services_name == "" ? "acs-appregmonitoring${var.environment}${random_string.main.result}" : var.communication_services_name
  parent_id = azurerm_resource_group.main.id
  location  = var.communication_services_location

  body = jsonencode({
    properties = {
      dataLocation  = var.data_location
      linkedDomains = [azapi_resource.domain.id]
    }
  })
  response_export_values = ["*"]
}

data "azurerm_communication_service" "main" {
  name                = azapi_resource.communication_services.name
  resource_group_name = azurerm_resource_group.main.name
}

# logic app for monitoring app reg secrets thats about to expire

data "azurerm_managed_api" "main" {
  name     = "acsemail"
  location = azurerm_resource_group.main.location
}

resource "azurerm_api_connection" "main" {
  name                = var.api_connection_name
  display_name        = var.api_connection_display_name
  resource_group_name = azurerm_resource_group.main.name
  managed_api_id      = data.azurerm_managed_api.main.id
  parameter_values = {
    api_key = data.azurerm_communication_service.main.primary_connection_string
  }
  lifecycle {
    ignore_changes = [
      parameter_values["api_key"]
    ]
  }
}

resource "azurerm_logic_app_workflow" "main" {
  name                = var.logic_app_workflow_name == "" ? "logic-appregmonitoring${var.environment}" : var.logic_app_workflow_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  parameters = {
    "$connections" = jsonencode(
      {
        acsemail = {
          connectionId   = azurerm_api_connection.main.id
          connectionName = azurerm_api_connection.main.name
          id             = "/subscriptions/${var.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/acsemail"
        }
      }
    )
  }
  workflow_parameters = {
    "$connections" = jsonencode(
      {
        defaultValue = {}
        type         = "Object"
      }
    )
  }
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_api_connection.main
  ]
}
resource "azurerm_logic_app_trigger_recurrence" "recurrence" {
  name         = "Recurrence"
  logic_app_id = azurerm_logic_app_workflow.main.id
  frequency    = var.logic_app_trigger_recurrence_frequency
  interval     = var.logic_app_trigger_recurrence_interval
}

resource "azurerm_logic_app_action_custom" "initialize_appid" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_appid"
  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "AppID"
          type  = "string"
          value = ""
        }
      ]
    }
    runAfter = {}
    type     = "InitializeVariable"
  })
  depends_on = [azurerm_logic_app_trigger_recurrence.recurrence]
}

resource "azurerm_logic_app_action_custom" "initialize_displayname" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_displayName"
  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "displayName"
          type  = "string"
          value = ""
        }
      ]
    }
    runAfter = {
      "Initialize_appid" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })
  depends_on = [azurerm_logic_app_action_custom.initialize_appid]
}

resource "azurerm_logic_app_action_custom" "initialize_passwordcredential" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_passwordCredential"
  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "passwordCredential"
          type  = "array"
          value = []
        }
      ]
    }
    runAfter = {
      "Initialize_displayName" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })
  depends_on = [azurerm_logic_app_action_custom.initialize_displayname]
}

resource "azurerm_logic_app_action_custom" "initialize_keycredential" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_-_keyCredential"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "keyCredential"
          type  = "array"
          value = []
        }
      ]
    }
    runAfter = {
      "Initialize_passwordCredential" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_passwordcredential
  ]
}

resource "azurerm_logic_app_action_custom" "initialize_styles" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_styles"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name = "styles"
          type = "object"
          value = {
            cellStyle   = "style=\"font-family: Calibri; padding: 5px; border: 1px solid black;\""
            headerStyle = "style=\"font-family: Helvetica; padding: 5px; border: 1px solid black;\""
            redStyle    = "style=\"background-color:red; font-family: Calibri; padding: 5px; border: 1px solid black;\""
            tableStyle  = "style=\"border-collapse: collapse;\""
            yellowStyle = "style=\"background-color:yellow; font-family: Calibri; padding: 5px; border: 1px solid black;\""
          }
        }
      ]
    }
    runAfter = {
      "Initialize_-_keyCredential" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_keycredential
  ]
}

resource "azurerm_logic_app_action_custom" "initialize_html" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_html"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "html"
          type  = "string"
          value = "<table  @{variables('styles').tableStyle}><thead><th  @{variables('styles').headerStyle}>Application ID</th><th  @{variables('styles').headerStyle}>Display Name</th><th @{variables('styles').headerStyle}> Key Id</th><th  @{variables('styles').headerStyle}>Days until Expiration</th><th  @{variables('styles').headerStyle}>Type</th><th  @{variables('styles').headerStyle}>Expiration Date</th><th @{variables('styles').headerStyle}>Owner</th></thead><tbody>"
        }
      ]
    }
    runAfter = {
      "Initialize_styles" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_styles
  ]
}

resource "azurerm_logic_app_action_custom" "initialize_emailneeded" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_emailNeeded"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "emailNeeded"
          type  = "boolean"
          value = false
        }
      ]
    }
    runAfter = {
      "Initialize_html" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_html
  ]
}

resource "azurerm_logic_app_action_custom" "initialize_daystilexpiration" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_daysTilExpiration"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "daysTilExpiration"
          type  = "float"
          value = 10
        }
      ]
    }
    runAfter = {
      "Initialize_emailNeeded" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_emailneeded
  ]
}

resource "azurerm_logic_app_action_custom" "initialize_nextlink" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Initialize_-_NextLink"

  body = jsonencode({
    inputs = {
      variables = [
        {
          name  = "NextLink"
          type  = "string"
          value = "https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,passwordCredentials,keyCredentials&$top=999"
        }
      ]
    }
    runAfter = {
      "Initialize_daysTilExpiration" = ["Succeeded"]
    }
    type = "InitializeVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_daystilexpiration
  ]
}

resource "azurerm_logic_app_action_custom" "until" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Until"

  body = jsonencode({
    actions = {
      "Foreach_-_apps" = {
        actions = {
          "For_each_-_PasswordCred" = {
            actions = {
              "Condition" = {
                actions = {
                  "DifferentAsDays" = {
                    inputs = "@div(div(div(mul(sub(outputs('EndTimeTickValue'), outputs('StartTimeTickValue')), 100), 1000000000), 3600), 24)"
                    runAfter = {
                      "StartTimeTickValue" = ["Succeeded"]
                    }
                    type = "Compose"
                  }
                  "EndTimeTickValue" = {
                    inputs   = "@ticks(item()?['endDateTime'])"
                    runAfter = {}
                    type     = "Compose"
                  }
                  "Get_Secret_Owner" = {
                    inputs = {
                      authentication = {
                        audience = "https://graph.microsoft.com"
                        type     = "ManagedServiceIdentity"
                      }
                      method = "GET"
                      uri    = "https://graph.microsoft.com/v1.0/applications/@{items('Foreach_-_apps')?['id']}/owners"
                    }
                    runAfter = {
                      "Set_variable" = ["Succeeded"]
                    }
                    type = "Http"
                  }
                  "In_Case_of_No_Owner" = {
                    actions = {
                      "Append_to_string_variable_4" = {
                        inputs = {
                          name  = "html"
                          value = "<tr><td @{variables('styles').cellStyle}><a href=\"https://ms.portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/@{variables('AppID')}/isMSAApp/\">@{variables('AppID')}</a></td><td @{variables('styles').cellStyle}>@{variables('displayName')}</td><td @{variables('styles').cellStyle}>@{items('For_each_-_PasswordCred')?['keyId']}</td><td @{if(less(variables('daysTilExpiration'), 100), variables('styles').redStyle, if(less(variables('daysTilExpiration'), 150), variables('styles').yellowStyle, variables('styles').cellStyle))}>@{variables('daysTilExpiration')}</td><td @{variables('styles').cellStyle}>Secret</td><td @{variables('styles').cellStyle}>@{formatDateTime(item()?['endDateTime'],'g')}</td><td @{variables('styles').cellStyle}>No Owner</td></tr>"
                        }
                        runAfter = {}
                        type     = "AppendToStringVariable"
                      }
                      "Set_send_email_to_true" = {
                        inputs = {
                          name  = "emailNeeded"
                          value = true
                        }
                        runAfter = {
                          "Append_to_string_variable_4" = ["Succeeded"]
                        }
                        type = "SetVariable"
                      }
                    }
                    else = {
                      actions = {
                        "Append_to_string_variable" = {
                          inputs = {
                            name  = "html"
                            value = "<tr><td @{variables('styles').cellStyle}><a href=\"https://ms.portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/@{variables('AppID')}/isMSAApp/\">@{variables('AppID')}</a></td><td @{variables('styles').cellStyle}>@{variables('displayName')}</td><td @{variables('styles').cellStyle}>@{items('For_each_-_PasswordCred')?['keyId']}</td><td @{if(less(variables('daysTilExpiration'), 100), variables('styles').redStyle, if(less(variables('daysTilExpiration'), 150), variables('styles').yellowStyle, variables('styles').cellStyle))}>@{variables('daysTilExpiration')}</td><td @{variables('styles').cellStyle}>Secret</td><td @{variables('styles').cellStyle}>@{formatDateTime(item()?['endDateTime'],'g')}</td><td @{variables('styles').cellStyle}><a href=\"mailto:@{body('Get_Secret_Owner')?['value'][0]?['userPrincipalName']}\">@{body('Get_Secret_Owner')?['value'][0]?['givenName']} @{body('Get_Secret_Owner')?['value'][0]?['surname']}</a></td></tr>"
                          }
                          runAfter = {}
                          type     = "AppendToStringVariable"
                        }
                        "Set_send_email_to_true_1" = {
                          inputs = {
                            name  = "emailNeeded"
                            value = true
                          }
                          runAfter = {
                            "Append_to_string_variable" = ["Succeeded"]
                          }
                          type = "SetVariable"
                        }
                      }
                    }
                    expression = {
                      and = [
                        {
                          equals = [
                            "@length(body('Get_Secret_Owner')?['value'])",
                            "@int('0')"
                          ]
                        }
                      ]
                    }
                    runAfter = {
                      "Get_Secret_Owner" = ["Succeeded"]
                    }
                    type = "If"
                  }
                  "Set_variable" = {
                    inputs = {
                      name  = "daysTilExpiration"
                      value = "@outputs('DifferentAsDays')"
                    }
                    runAfter = {
                      "DifferentAsDays" = ["Succeeded"]
                    }
                    type = "SetVariable"
                  }
                  "StartTimeTickValue" = {
                    inputs = "@ticks(utcnow())"
                    runAfter = {
                      "EndTimeTickValue" = ["Succeeded"]
                    }
                    type = "Compose"
                  }
                }
                expression = {
                  and = [
                    {
                      greaterOrEquals = [
                        "@body('Get_future_time')",
                        "@items('For_each_-_PasswordCred')?['endDateTime']"
                      ]
                    }
                  ]
                }
                runAfter = {}
                type     = "If"
              }
            }
            foreach = "@items('Foreach_-_apps')?['passwordCredentials']"
            runAfter = {
              "Set_variable_-_keyCredential" = ["Succeeded"]
            }
            type = "Foreach"
          }
          "For_each_KeyCred" = {
            actions = {
              "Condition_2" = {
                actions = {
                  "Condition_5" = {
                    actions = {
                      "Append_Certificate_to_HTML_without_owner" = {
                        inputs = {
                          name  = "html"
                          value = "<tr><td @{variables('styles').cellStyle}><a href=\"https://ms.portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/@{variables('AppID')}/isMSAApp/\">@{variables('AppID')}</a></td><td @{variables('styles').cellStyle}>@{variables('displayName')}</td><td @{variables('styles').cellStyle}>@{items('For_each_KeyCred')?['keyId']}</td><td @{if(less(variables('daysTilExpiration'), 15), variables('styles').redStyle, if(less(variables('daysTilExpiration'), 30), variables('styles').yellowStyle, variables('styles').cellStyle))}>@{variables('daysTilExpiration')}</td><td @{variables('styles').cellStyle}>Certificate</td><td @{variables('styles').cellStyle}>@{formatDateTime(item()?['endDateTime'], 'g')}</td><td @{variables('styles').cellStyle}>No Owner</td></tr>"
                        }
                        runAfter = {}
                        type     = "AppendToStringVariable"
                      }
                      "set_sendemail_to_true_2" = {
                        inputs = {
                          name  = "emailNeeded"
                          value = true
                        }
                        runAfter = {
                          "Append_Certificate_to_HTML_without_owner" = ["Succeeded"]
                        }
                        type = "SetVariable"
                      }
                    }
                    else = {
                      actions = {
                        "Append_Certificate_to_HTML_with_owner" = {
                          inputs = {
                            name  = "html"
                            value = "<tr><td @{variables('styles').cellStyle}><a href=\"https://ms.portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Credentials/appId/@{variables('AppID')}/isMSAApp/\">@{variables('AppID')}</a></td><td @{variables('styles').cellStyle}>@{variables('displayName')}</td><td @{variables('styles').cellStyle}>@{items('For_each_KeyCred')?['keyId']}</td><td @{if(less(variables('daysTilExpiration'), 15), variables('styles').redStyle, if(less(variables('daysTilExpiration'), 30), variables('styles').yellowStyle, variables('styles').cellStyle))}>@{variables('daysTilExpiration')}</td><td @{variables('styles').cellStyle}>Certificate</td><td @{variables('styles').cellStyle}>@{formatDateTime(item()?['endDateTime'], 'g')}</td><td @{variables('styles').cellStyle}><a href=\"mailto:@{body('Get_Certificate_Owner')?['value'][0]?['userPrincipalName']}\">@{body('Get_Certificate_Owner')?['value'][0]?['givenName']} @{body('Get_Certificate_Owner')?['value'][0]?['surname']}</a></td></tr>"
                          }
                          runAfter = {}
                          type     = "AppendToStringVariable"
                        }
                        "set_sendemail_to_true_3" = {
                          inputs = {
                            name  = "emailNeeded"
                            value = true
                          }
                          runAfter = {
                            "Append_Certificate_to_HTML_with_owner" = ["Succeeded"]
                          }
                          type = "SetVariable"
                        }
                      }
                    }
                    expression = {
                      and = [
                        {
                          equals = [
                            "@length(body('Get_Certificate_Owner')?['value'])",
                            "@int('0')"
                          ]
                        }
                      ]
                    }
                    runAfter = {
                      "Get_Certificate_Owner" = ["Succeeded"]
                    }
                    type = "If"
                  }
                  "DifferentAsDays2" = {
                    inputs = "@div(div(div(mul(sub(outputs('EndTimeTickValue2'), outputs('StartTimeTickValue2')), 100), 1000000000), 3600), 24)"
                    runAfter = {
                      "StartTimeTickValue2" = ["Succeeded"]
                    }
                    type = "Compose"
                  }
                  "EndTimeTickValue2" = {
                    inputs   = "@ticks(item()?['endDateTime'])"
                    runAfter = {}
                    type     = "Compose"
                  }
                  "Get_Certificate_Owner" = {
                    inputs = {
                      authentication = {
                        audience = "https://graph.microsoft.com"
                        type     = "ManagedServiceIdentity"
                      }
                      method = "GET"
                      uri    = "https://graph.microsoft.com/v1.0/applications/@{items('Foreach_-_apps')?['id']}/owners"
                    }
                    runAfter = {
                      "Store_Days_till_expiration" = ["Succeeded"]
                    }
                    type = "Http"
                  }
                  "StartTimeTickValue2" = {
                    inputs = "@ticks(utcnow())"
                    runAfter = {
                      "EndTimeTickValue2" = ["Succeeded"]
                    }
                    type = "Compose"
                  }
                  "Store_Days_till_expiration" = {
                    inputs = {
                      name  = "daysTilExpiration"
                      value = "@outputs('DifferentAsDays2')"
                    }
                    runAfter = {
                      "DifferentAsDays2" = ["Succeeded"]
                    }
                    type = "SetVariable"
                  }
                }
                expression = {
                  and = [
                    {
                      greaterOrEquals = [
                        "@body('Get_future_time')",
                        "@items('For_each_KeyCred')?['endDateTime']"
                      ]
                    }
                  ]
                }
                runAfter = {}
                type     = "If"
              }
            }
            foreach = "@items('Foreach_-_apps')?['keyCredentials']"
            runAfter = {
              "For_each_-_PasswordCred" = ["Succeeded"]
            }
            type = "Foreach"
          }
          "Set_variable_-_appId" = {
            inputs = {
              name  = "AppID"
              value = "@items('Foreach_-_apps')?['appId']"
            }
            runAfter = {}
            type     = "SetVariable"
          }
          "Set_variable_-_displayName" = {
            inputs = {
              name  = "displayName"
              value = "@items('Foreach_-_apps')?['displayName']"
            }
            runAfter = {
              "Set_variable_-_appId" = ["Succeeded"]
            }
            type = "SetVariable"
          }
          "Set_variable_-_keyCredential" = {
            inputs = {
              name  = "keyCredential"
              value = "@items('Foreach_-_apps')?['keyCredentials']"
            }
            runAfter = {
              "Set_variable_-_passwordCredential" = ["Succeeded"]
            }
            type = "SetVariable"
          }
          "Set_variable_-_passwordCredential" = {
            inputs = {
              name  = "passwordCredential"
              value = "@items('Foreach_-_apps')?['passwordCredentials']"
            }
            runAfter = {
              "Set_variable_-_displayName" = ["Succeeded"]
            }
            type = "SetVariable"
          }
        }
        foreach = "@body('Parse_JSON')?['value']"
        runAfter = {
          "Get_future_time" = ["Succeeded"]
        }
        runtimeConfiguration = {
          concurrency = {
            repetitions = 1
          }
        }
        type = "Foreach"
      }
      "Get_future_time" = {
        inputs = {
          interval = var.logic_app_trigger_get_future_time_interval
          timeUnit = "${var.logic_app_trigger_get_future_time_time_unit}"
        }
        kind = "GetFutureTime"
        runAfter = {
          "Parse_JSON" = ["Succeeded"]
        }
        type = "Expression"
      }
      "HTTP_-_Get_AzureAD_Applications" = {
        inputs = {
          authentication = {
            audience = "https://graph.microsoft.com"
            type     = "ManagedServiceIdentity"
          }
          method = "GET"
          uri    = "@variables('NextLink')"
        }
        runAfter = {}
        type     = "Http"
      }
      "Parse_JSON" = {
        inputs = {
          content = "@body('HTTP_-_Get_AzureAD_Applications')"
          schema = {
            type = "object"
            properties = {
              "@@odata.context" = {
                type = "string"
              }
              "value" = {
                type = "array"
                items = {
                  type = "object"
                  properties = {
                    "appId"               = { type = "string" }
                    "displayName"         = { type = "string" }
                    "keyCredentials"      = { type = "array" }
                    "passwordCredentials" = { type = "array" }
                  }
                }
              }
            }
            additionalProperties = true
          }
        }
        runAfter = {
          "HTTP_-_Get_AzureAD_Applications" = ["Succeeded"]
        }
        type = "ParseJson"
      }
      "Update_Next_Link" = {
        inputs = {
          name  = "NextLink"
          value = "@{body('Parse_JSON')?['@@odata.nextLink']}"
        }
        runAfter = {
          "Foreach_-_apps" = ["Succeeded"]
        }
        type = "SetVariable"
      }
    }
    expression = "@not(equals(variables('NextLink'), null))"
    limit = {
      count   = 60
      timeout = "PT1H"
    }
    runAfter = {
      "Initialize_-_NextLink" = ["Succeeded"]
    }
    type = "Until"
  })

  depends_on = [
    azurerm_logic_app_action_custom.initialize_nextlink
  ]
}



resource "azurerm_logic_app_action_custom" "close_html_tags" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Close_HTML_tags"

  body = jsonencode({
    inputs = {
      name  = "html"
      value = "<tbody></table>"
    }
    runAfter = {
      "Until" = ["Succeeded"]
    }
    type = "AppendToStringVariable"
  })

  depends_on = [
    azurerm_logic_app_action_custom.until
  ]
}

resource "azurerm_logic_app_action_custom" "condition_emailneeded" {
  logic_app_id = azurerm_logic_app_workflow.main.id
  name         = "Condition_emailNeeded"

  body = jsonencode({
    actions = {
      "Send_email" = {
        inputs = {
          body = {
            content = {
              html    = "<p>@{variables('html')}</p>"
              subject = "${var.email_subject}"
            }
            importance = "Normal"
            recipients = {
              to = [
                for email in var.email_recipients : {
                  address = email
                }
              ]
            }
            senderAddress = "DoNotReply@${jsondecode(azapi_resource.domain.output).properties.mailFromSenderDomain}"
          }
          host = {
            connection = {
              name = "@parameters('$connections')['acsemail']['connectionId']"
            }
          }
          method = "post"
          path   = "/emails:sendGAVersion"
          queries = {
            "api-version" = "2023-03-31"
          }
        }
        runAfter = {}
        type     = "ApiConnection"
      }
    }
    expression = {
      and = [
        {
          equals = [
            "@variables('emailNeeded')",
            true
          ]
        }
      ]
    }
    runAfter = {
      "Close_HTML_tags" = ["Succeeded"]
    }
    type = "If"
  })

  depends_on = [
    azurerm_logic_app_action_custom.close_html_tags
  ]
}
