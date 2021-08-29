output "lambda_role" {
  description = "IAM Role object used for the Lambda function"
  value       = aws_iam_role.lambda_role
}

