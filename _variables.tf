variable "region" {
  description = "The region where the AWS infrastructure is hosted."
  default     = "us-east-1"
  type        = string
}

variable "project_name" {
  description = "The name prefix of the project."
  type        = string
  default     = "minecraft-cloud"
}

variable "rcon_password" {
  description = "The password for RCON."
  type        = string
  default     = "minecraft"
}

variable "container_name" {
  description = "The name of the container that runs the Minecraft server."
  type        = string
  default     = "minecraft-server"
}

variable "memory" {
  description = "The memory of the Minecraft server in Megabytes (MB)."
  type        = number
  default     = 8192
}

variable "op_admin_username" {
  description = "The Minecraft in-game username of the admin of the server that is given the role of op."
  type        = string
  default     = ""
}

variable "world_name" {
  description = "The unique identifier for the world map save.  If you change this the server will start with the latest world data for that save, or it will create a new world if none exists."
  type        = string
  default     = "myworld"
}

variable "whitelisted_minecraft_usernames" {
  description = "A list of comma separated usernames that are allowed to join the server."
  type        = string
  default     = ""
}

variable "minecraft_server_subdomain" {
  description = "The subdomain name of the Minecraft server."
  type        = string
  default     = "minecraft"
}

variable "minecraft_server_domain" {
  description = "The domain name of the Minecraft server that must be an existing R53 public hosted zone."
  type        = string
}

variable "rcon_port" {
  description = "The port number that exposes RCON."
  type        = string
  default     = "25575"
}
