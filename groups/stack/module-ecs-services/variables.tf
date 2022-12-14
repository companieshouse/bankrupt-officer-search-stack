# Environment
variable "environment" {
  type        = string
  description = "The environment name, defined in environments vars."
}
variable "aws_region" {
  type        = string
  description = "The AWS region for deployment."
}

# Networking
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC for the target group and security group."
}
variable "bados-web-lb-arn" {
  type        = string
  description = "The ARN of the load balancer created in the ecs-stack module."
}
variable "bados-web-lb-listener-arn" {
  type        = string
  description = "The ARN of the lb listener created in the ecs-stack module."
}
variable "subnet_ids" {
  type        = string
  description = "Subnet IDs of application subnets from aws-mm-networks remote state."
}
variable "web_access_cidrs" {
  type        = list(string)
  description = "Subnet CIDRs for web ingress rules in the security group."
}

# DNS
variable "external_top_level_domain" {
  type        = string
  description = "The type levelel of the DNS domain for external access."
}
variable "internal_top_level_domain" {
  type        = string
  description = "The type levelel of the DNS domain for internal access."
}
variable "account_subdomain_prefix" {
  type = string
}

# ECS Service
variable "name_prefix" {
  type        = string
  description = "The name prefix to be used for stack / environment name spacing."
}
variable "ecs_cluster_id" {
  type        = string
  description = "The ARN of the ECS cluster to deploy the service to."
}

# Docker Container
variable "docker_registry" {
  type        = string
  description = "The FQDN of the Docker registry."
}
variable "task_execution_role_arn" {
  type        = string
  description = "The ARN of the task execution role that the container can assume."
}
variable "log_level" {
  type        = string
  description = "The log level to be set in the environment variables for the container."
}

# Cookies
variable "cookie_domain" {
  type        = string
  description = "The session cookie domain."
}
variable "cookie_name" {
  type        = string
  description = "The cookie name."
}

# Certificates
variable "ssl_certificate_id" {
  type        = string
  description = "The ARN of the certificate for https access through the ALB."
}

# Secrets
variable "secrets_arn_map" {
  type = map(string)
  description = "The ARNs for all secrets"
}

# ------------------------------------------------------------------------------

# bankrupt-officer-search-web
variable "bados_web_release_version" {
  type        = string
  description = "The release version for the bankrupt-officer-search-web service."
}
variable "bados_web_application_port" {
  type        = string
  description = "The port number for the bankrupt-officer-search-web service."
}
variable "bados_web_oauth2_redirect_uri" {
  type = string
}
variable "bados_web_oauth2_token_uri" {
  type = string
  description = "The uri of the oauth token refresh endpoint"
}
variable "bados_web_cdn_host" {
  type        = string
  description = "The host URL for the CDN"
}
variable "bados_web_chs_url" {
  type        = string
  description = "The URL for CHS"
}
variable "bados_web_account_url" {
  type        = string
  description = "The URL for CHS Account"
}
variable "bados_web_monitor_url" {
  type        = string
  description = "The URL for CHS Follow"
}
variable "bados_web_cache_pool_size" {
  type        = number
  description = "The max size of the pool of connections to the cache"
}
variable "bados_web_cache_server" {
  type        = string
  description = "The server name of the cache"
}
variable "bados_web_default_session_expiration" {
  type        = number
  description = "Default session expiration in seconds"
}
variable "internal_api_url" {
  type        = string
  description = "The internal URL for the Companies House API service."
}
variable "api_url" {
  type        = string
  description = "The URL for the Companies House API service."
}