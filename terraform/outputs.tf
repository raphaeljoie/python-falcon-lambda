output "lambda_role" {
  description = "IAM Role object used for the Lambda function"
  value       = aws_iam_role.lambda_role
}

output "lambda_source_code_hash" {
  value = filebase64sha256("${var.lambda_folder}/${local.zip_filename}")
}
