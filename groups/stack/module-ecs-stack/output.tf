output "bados-web-lb-listener-arn" {
  value = aws_lb_listener.bados-web-lb-listener.arn
}

output "bados-web-lb-arn" {
  value = aws_lb.bados-web-lb.arn
}