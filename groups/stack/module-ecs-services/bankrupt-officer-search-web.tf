locals {
  service_name = "bankrupt-officer-search-web"
  bankrupt_officer_search_proxy_port = 11000 # local port number defined for proxy target of bankrupt officer search service sitting behind eric
}

resource "aws_ecs_service" "bankrupt-officer-search-web-ecs-service" {
  name            = "${var.environment}-${local.service_name}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.bankrupt-officer-search-web-td.arn
  desired_count   = 1
  depends_on      = [var.bankrupt-officer-search-web-lb-arn]
  load_balancer {
    target_group_arn = aws_lb_target_group.bankrupt-officer-search-web-tg.arn
    container_port   = var.bankrupt_officer_search_web_application_port
    container_name   = "eric" # [ALB -> target group -> eric -> bankrupt officer search web] so eric container named here
  }
}

locals {
  definition = merge(
    {
      service_name               : local.service_name
      environment                : var.environment
      name_prefix                : var.name_prefix
      aws_region                 : var.aws_region
      external_top_level_domain  : var.external_top_level_domain
      account_subdomain_prefix   : var.account_subdomain_prefix
      log_level                  : var.log_level
      docker_registry            : var.docker_registry
      cookie_domain              : var.cookie_domain
      cookie_name                : var.cookie_name

      # eric specific configs
      eric_port                      : var.bankrupt_officer_search_web_application_port # eric needs to be the first service in the chain from ALB
      eric_version                   : var.eric_version
      eric_cache_url                 : var.eric_cache_url
      eric_cache_max_connections     : var.eric_cache_max_connections
      eric_cache_max_idle            : var.eric_cache_max_idle
      eric_cache_idle_timeout        : var.eric_cache_idle_timeout
      eric_cache_ttl                 : var.eric_cache_ttl
      eric_flush_interval            : var.eric_flush_interval
      eric_graceful_shutdown_period  : var.eric_graceful_shutdown_period
      eric_default_rate_limit        : var.eric_default_rate_limit
      eric_default_rate_limit_window : var.eric_default_rate_limit_window

      # api configs      
      internal_api_url                   : var.internal_api_url
      api_url                            : var.api_url

      # bankrupt_officer_search specific configs
      bankrupt_officer_search_web_release_version            : var.bankrupt_officer_search_web_release_version
      bankrupt_officer_search_proxy_port                     : local.bankrupt_officer_search_proxy_port
      bankrupt_officer_search_web_oauth2_redirect_uri        : var.bankrupt_officer_search_web_oauth2_redirect_uri
      bankrupt_officer_search_web_oauth2_token_uri           : var.bankrupt_officer_search_web_oauth2_token_uri
      bankrupt_officer_search_web_cdn_host                   : var.bankrupt_officer_search_web_cdn_host
      bankrupt_officer_search_web_chs_url                    : var.bankrupt_officer_search_web_chs_url
      bankrupt_officer_search_web_account_url                : var.bankrupt_officer_search_web_account_url
      bankrupt_officer_search_web_monitor_url                : var.bankrupt_officer_search_web_monitor_url
      bankrupt_officer_search_web_cache_pool_size            : var.bankrupt_officer_search_web_cache_pool_size
      bankrupt_officer_search_web_cache_server               : var.bankrupt_officer_search_web_cache_server
      bankrupt_officer_search_web_default_session_expiration : var.bankrupt_officer_search_web_default_session_expiration
    },
      var.secrets_arn_map
  )
}

resource "aws_ecs_task_definition" "bankrupt-officer-search-web-task-definition" {
  family                = "${var.environment}-${local.service_name}"
  execution_role_arn    = var.task_execution_role_arn
  container_definitions = templatefile(
    "${path.module}/${local.service_name}-task-definition.tmpl", local.definition
  )
}

resource "aws_lb_target_group" "bankrupt-officer-search-web-tg" {
  name     = "${var.environment}-${local.service_name}"
  port     = var.bankrupt_officer_search_web_application_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener_rule" "bankrupt-officer-search-web" {
  listener_arn = var.bankrupt-officer-search-web-lb-listener-arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bankrupt-officer-search-web-target_group.arn
  }
  condition {
    field  = "path-pattern"
    values = ["*"]
  }
}