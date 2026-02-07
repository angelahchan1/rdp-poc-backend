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

variable "smb_server_ip" {
  description = "The IP address for the smb server"
  type        = string
  sensitive   = true

}

variable "smb_password" {
  description = "The password for the smb server"
  type        = string
  sensitive   = true

}

variable "smb_username" {
  description = "The username for the smb server"
  type        = string
  sensitive   = true

}

variable "smb_subdirectory" {
  description = "The subdirectory for the smb server"
  type        = string
}



