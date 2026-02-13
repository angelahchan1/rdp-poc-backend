variable "project_prefix" { type = string }
variable "account_id" { type = string }
variable "region_id" { type = string }

variable "datasync_activation_key" {
  type      = string
  sensitive = true
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
