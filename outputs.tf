output "instance_id" {
  value = aws_instance.log_server.id
}

output "log_group" {
  value = aws_cloudwatch_log_group.app_logs.name
}