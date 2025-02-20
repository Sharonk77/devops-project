output "load_balancer_url" {
  description = "The Load Balancer URL"
  value       = aws_lb.ecs_lb.dns_name
}