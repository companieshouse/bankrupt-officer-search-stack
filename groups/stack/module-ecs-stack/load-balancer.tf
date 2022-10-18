resource "aws_lb" "bankrupt-officer-search-web-lb" {
  name            = "${var.stack_name}-${var.environment}-lb"
  security_groups = [aws_security_group.internal-service-sg.id]
  subnets         = flatten([split(",", var.subnet_ids)])
  internal        = var.bankrupt_officer_search_web_lb_internal
}

resource "aws_lb_listener" "bankrupt-officer-search-web-lb-listener" {
  load_balancer_arn = aws_lb.bankrupt-officer-search-web-lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_id
  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "OK"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "bankrupt-officer-search-web-lb-http-listener" {
  load_balancer_arn = aws_lb.bankrupt-officer-search-web-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "bankrupt-officer-search-web-r53-record" {
  count   = var.zone_id == "" ? 0 : 1 # zone_id defaults to empty string giving count = 0 i.e. not route 53 record
  zone_id = var.zone_id
  name    = "bankrupt-officer-search-web${var.external_top_level_domain}"
  type    = "A"
  alias {
    name                   = aws_lb.bankrupt-officer-search-web-lb.dns_name
    zone_id                = aws_lb.bankrupt-officer-search-web-lb.zone_id
    evaluate_target_health = false
  }
}