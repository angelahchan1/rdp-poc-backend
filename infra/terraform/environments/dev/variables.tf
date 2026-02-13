variable "environment" {
  description = "The deployment environment."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "The project name."
  type        = string
  default     = "rdp" #short for rail defect poc
}


variable "datasync_activation_key" {
  description = "The activation key for the data sync agent"
  type        = string
  sensitive   = true
}

variable "smb_config" {
  description = "Connection details for the SMB server"
  type = object({
    server_ip    = string
    username     = string
    password     = string
    subdirectory = string
  })
  sensitive = true
}
