variable "environment" {
  description = "Short name of the environment. This is used in the naming convention of resource creation. If resource names are overwritten, this environment variable is not used for that resource"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group"
  type        = string
  default     = ""
}

variable "email_communication_service_name" {
  description = "The name of the Email Communication Service"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "The Resource Name of the domain"
  type        = string
  default     = "AzureManagedDomain"
}

variable "communication_services_name" {
  description = "The name of the communication service"
  type        = string
  default     = ""
}

variable "api_connection_name" {
  description = "The name of the mail api-connection"
  type        = string
  default     = "acsemail"
}

variable "api_connection_display_name" {
  description = "The display name of the mail api-connection"
  type        = string
  default     = "Azure Communication Email"
}

variable "logic_app_workflow_name" {
  description = "The name of the Logic App Workflow"
  type        = string
  default     = ""
}

variable "resource_location" {
  description = "The location of Resource Group and Logic App"
  type        = string
}

variable "communication_services_location" {
  description = "The geo-location where the communication services lives"
  type        = string
  default     = "global"
}

variable "data_location" {
  description = "The location where the Communication service store its data at rest."
  type        = string
  validation {
    condition     = contains(["Africa", "Asia Pacific", "Australia", "Brazil", "Canada", "Europe", "France", "Germany", "India", "Japan", "Korea", "Norway", " Switzerland", "UAE", "UK", "United States"], var.data_location)
    error_message = "Valid value is one of the following: Africa, Asia Pacific, Australia, Brazil, Canada, Europe, France, Germany, India, Japan, Korea, Norway, Switzerland, UAE, UK, United States"
  }
}

variable "subscription_id" {
  description = "Subscription id used when referencing to the API-Connection in the Logic App Workflow"
}

variable "logic_app_trigger_recurrence_frequency" {
  description = "The frequency of the Logic App trigger"
  type        = string
  validation {
    condition     = contains(["Month", "Week", "Day", "Hour", "Minute", "Second"], var.logic_app_trigger_recurrence_frequency)
    error_message = "Valid value is one of the following: Month, Week, Day, Hour, Minute, Second"
  }
  default = "Day"
}

variable "logic_app_trigger_recurrence_interval" {
  description = "The interval of the Logic App trigger"
  type        = number
  default     = 4
}

variable "logic_app_trigger_get_future_time_interval" {
  description = "The limit interval of credentials being alerted"
  type = number
  default = 1
}

variable "logic_app_trigger_get_future_time_time_unit" {
  description = "The limit unit of credentials being alerted"
  type = string
  validation {
    condition     = contains(["Month", "Week", "Day", "Hour", "Minute", "Second"], var.logic_app_trigger_get_future_time_time_unit)
    error_message = "Valid value is one of the following: Month, Week, Day, Hour, Minute, Second"
  }
  default = "Month"
}

variable "email_subject" {
  description = "The subject of the email being sent"
  type        = string
  default     = "List of Secrets and Certificates near expiration"
}

variable "email_recipients" {
  description = "List of email recipients"
  type        = list(string)
}


