output "lambda_role" {
  description = "IAM Role object used for the Lambda function"
  value       = aws_iam_role.lambda_role
}

output "api_url" {
  description = "API URL for each stages"
  value       = aws_api_gateway_deployment.deployment[*].invoke_url
}
