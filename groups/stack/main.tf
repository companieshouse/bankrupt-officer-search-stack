provider "aws" {
  region  = var.aws_region
  version = "~> 2.32.0"
}

terraform {
  backend "s3" {
  }
}

# Configure the remote state data source to acquire configuration
# created through the code in ch-service-terraform/aws-mm-networks.
data "terraform_remote_state" "networks" {
  backend = "s3"
  config = {
    bucket = var.remote_state_bucket
    key    = "${var.state_prefix}/${var.deploy_to}/${var.deploy_to}.tfstate"
    region = var.aws_region
  }
}
locals {
  vpc_id            = data.terraform_remote_state.networks.outputs.vpc_id
  application_ids   = data.terraform_remote_state.networks.outputs.application_ids
  application_cidrs = data.terraform_remote_state.networks.outputs.application_cidrs
  public_ids        = data.terraform_remote_state.networks.outputs.public_ids
  public_cidrs      = data.terraform_remote_state.networks.outputs.public_cidrs
}

# Configure the remote state data source to acquire configuration created
# through the code in aws-common-infrastructure-terraform/groups/networking.
data "terraform_remote_state" "networks_common_infra" {
  backend = "s3"
  config = {
    bucket = var.aws_bucket
    key    = "aws-common-infrastructure-terraform/common-${var.aws_region}/networking.tfstate"
    region = var.aws_region
  }
}
locals {
  internal_cidrs = values(data.terraform_remote_state.networks_common_infra.outputs.internal_cidrs)
  vpn_cidrs      = values(data.terraform_remote_state.networks_common_infra.outputs.vpn_cidrs)
}

# Remote state data source for Ireland, required for Concourse management CIDRs
data "terraform_remote_state" "networks_common_infra_ireland" {
  backend = "s3"
  config = {
    bucket = "development-eu-west-1.terraform-state.ch.gov.uk"
    key    = "aws-common-infrastructure-terraform/common-eu-west-1/networking.tfstate"
    region = "eu-west-1"
  }
}
locals {
  management_private_subnet_cidrs = values(data.terraform_remote_state.networks_common_infra_ireland.outputs.management_private_subnet_cidrs)
}

# Configure the remote state data source to acquire configuration
# created through the code in the services-stack-configs stack in the
# aws-common-infrastructure-terraform repo.
data "terraform_remote_state" "services-stack-configs" {
  backend = "s3"
  config = {
    bucket = var.aws_bucket # aws-common-infrastructure-terraform repo uses the same remote state bucket
    key    = "aws-common-infrastructure-terraform/common-${var.aws_region}/services-stack-configs.tfstate"
    region = var.aws_region
  }
}

provider "vault" {
  auth_login {
    path = "auth/userpass/login/${var.vault_username}"
    parameters = {
      password = var.vault_password
    }
  }
}

data "vault_generic_secret" "secrets" {
  path = "applications/${var.aws_profile}/${var.environment}/${local.stack_fullname}"
}

locals {
  # stack name is hardcoded here in main.tf for this stack. It should not be overridden per env
  stack_name       = "bankrupt-officer-search"
  stack_fullname   = "${local.stack_name}-stack"
  name_prefix      = "${local.stack_name}-${var.environment}"

  public_lb_cidrs  = ["0.0.0.0/0"]
  lb_subnet_ids    = "${var.bados_web_lb_internal ? local.application_ids : local.public_ids}" # place ALB in correct subnets
  lb_access_cidrs  = "${var.bados_web_lb_internal?
                      concat(local.internal_cidrs,local.vpn_cidrs,local.management_private_subnet_cidrs,split(",",local.application_cidrs)) :
                      local.public_lb_cidrs }"
  app_access_cidrs = "${var.bados_web_lb_internal ?
                      concat(local.internal_cidrs,local.vpn_cidrs,local.management_private_subnet_cidrs,split(",",local.application_cidrs)) :
                      concat(local.internal_cidrs,local.vpn_cidrs,local.management_private_subnet_cidrs,split(",",local.application_cidrs),split(",",local.public_cidrs)) }"
}

module "ecs-cluster" {
  source = "git::git@github.com:companieshouse/terraform-library-ecs-cluster.git?ref=1.1.3"

  stack_name                 = local.stack_name
  name_prefix                = local.name_prefix
  environment                = var.environment
  vpc_id                     = local.vpc_id
  subnet_ids                 = local.application_ids
  ec2_key_pair_name          = var.ec2_key_pair_name
  ec2_instance_type          = var.ec2_instance_type
  ec2_image_id               = var.ec2_image_id
  asg_max_instance_count     = var.asg_max_instance_count
  asg_min_instance_count     = var.asg_min_instance_count
  asg_desired_instance_count = var.asg_desired_instance_count
}

module "secrets" {
  source = "./module-secrets"

  stack_name  = local.stack_name
  name_prefix = local.name_prefix
  environment = var.environment
  kms_key_id  = data.terraform_remote_state.services-stack-configs.outputs.services_stack_configs_kms_key_id
  secrets     = data.vault_generic_secret.secrets.data
}

module "ecs-stack" {
  source = "./module-ecs-stack"

  stack_name                 = local.stack_name
  name_prefix                = local.name_prefix
  environment                = var.environment
  vpc_id                     = local.vpc_id
  ssl_certificate_id         = var.ssl_certificate_id
  zone_id                    = var.zone_id
  external_top_level_domain  = var.external_top_level_domain
  internal_top_level_domain  = var.internal_top_level_domain
  subnet_ids                 = local.lb_subnet_ids
  web_access_cidrs           = local.lb_access_cidrs
  bados_web_lb_internal      = var.bados_web_lb_internal
}

module "ecs-services" {
  source = "./module-ecs-services"

  name_prefix               = local.name_prefix
  environment               = var.environment
  bados-web-lb-arn          = module.ecs-stack.bados-web-lb-listener-arn
  bados-web-lb-listener-arn = module.ecs-stack.bados-web-lb-listener-arn
  vpc_id                    = local.vpc_id
  subnet_ids                = local.application_ids
  web_access_cidrs          = local.app_access_cidrs
  aws_region                = var.aws_region
  ssl_certificate_id        = var.ssl_certificate_id
  external_top_level_domain = var.external_top_level_domain
  internal_top_level_domain = var.internal_top_level_domain
  account_subdomain_prefix  = var.account_subdomain_prefix
  ecs_cluster_id            = module.ecs-cluster.ecs_cluster_id
  task_execution_role_arn   = module.ecs-cluster.ecs_task_execution_role_arn
  docker_registry           = var.docker_registry
  secrets_arn_map           = module.secrets.secrets_arn_map
  log_level                 = var.log_level
  cookie_domain             = var.cookie_domain
  cookie_name               = var.cookie_name

  # eric specific configs
  eric_version                   = var.eric_version
  eric_cache_url                 = var.eric_cache_url
  eric_cache_max_connections     = var.eric_cache_max_connections
  eric_cache_max_idle            = var.eric_cache_max_idle
  eric_cache_idle_timeout        = var.eric_cache_idle_timeout
  eric_cache_ttl                 = var.eric_cache_ttl
  eric_flush_interval            = var.eric_flush_interval
  eric_graceful_shutdown_period  = var.eric_graceful_shutdown_period
  eric_default_rate_limit        = var.eric_default_rate_limit
  eric_default_rate_limit_window = var.eric_default_rate_limit_window

  # api configs
  internal_api_url                   = var.internal_api_url
  api_url                            = var.api_url

  # bankrupt-officer-search-stack variables
  bados_web_release_version            = var.bados_web_release_version
  bados_web_application_port           = "10000"
  bados_web_oauth2_redirect_uri        = var.bados_web_oauth2_redirect_uri
  bados_web_oauth2_token_uri           = var.bados_web_oauth2_token_uri
  bados_web_cdn_host                   = var.bados_web_cdn_host
  bados_web_chs_url                    = var.bados_web_chs_url
  bados_web_account_url                = var.bados_web_account_url
  bados_web_monitor_url                = var.bados_web_monitor_url
  bados_web_cache_pool_size            = var.bados_web_cache_pool_size
  bados_web_cache_server               = var.bados_web_cache_server
  bados_web_default_session_expiration = var.bados_web_default_session_expiration
}