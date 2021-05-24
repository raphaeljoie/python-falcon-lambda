locals {
  environment_map = var.lambda_environment == null ? [] : [var.lambda_environment]
  zip_filename = "build/lambda.zip"
}

locals {
  endpoint_list = flatten([
    for e in var.api_endpoints : [
      for m in e.method : {
        name             = e.name,
        name_with_method = "${e.name}-${m}",
        path             = e.path,
        method           = m,
        parent           = e.parent
      }
    ]
  ])
}



#### IAM Permissions

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda_role" {
  name = var.lambda_iam_role

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda_policy" {
  name        = var.lambda_iam_policy
  path        = "/"
  description = "IAM policy for the lambda function ' ${var.lambda_name} '"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
          "Action": [
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Resource": "arn:aws:logs:*:*:*",
          "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#### LAMBDA FUNCTION
resource "aws_s3_bucket_object" "lambda_version" {
  bucket = var.lambda_bucket_name
  key = "${var.lambda_name}/${var.lambda_version}/${local.zip_filename}"
  source = "${var.lambda_folder}/${local.zip_filename}"

  depends_on = [
    null_resource.zip_file
  ]
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.lambda_name

  s3_bucket = var.lambda_bucket_name
  s3_key = "${var.lambda_name}/${var.lambda_version}/${local.zip_filename}"

  runtime = var.lambda_runtime
  handler = var.lambda_handler
  timeout = var.lambda_timeout

  role = aws_iam_role.lambda_role.arn

  dynamic "environment" {
    for_each = local.environment_map
    content {
      variables = environment.value
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda_log_group,
    null_resource.zip_file,
    aws_s3_bucket_object.lambda_version
  ]

  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }
}

#### API GATEWAY
resource "aws_api_gateway_rest_api" "api" {
  name = var.api_name

  tags = var.tags
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowedAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"

  depends_on = [
    aws_api_gateway_rest_api.api,
    aws_lambda_function.lambda
  ]
}

# Parent resources
resource "aws_api_gateway_resource" "resource" {
  for_each = { for endpoint in var.api_endpoints : endpoint.name => endpoint if endpoint.parent == "root" }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.path
}

# Child resources
resource "aws_api_gateway_resource" "child_resource" {
  for_each = { for endpoint in var.api_endpoints : endpoint.name => endpoint if endpoint.parent != "root" }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.resource[each.value.parent].id
  path_part   = each.value.path
}

resource "aws_api_gateway_method" "method" {
  for_each = { for endpoint in local.endpoint_list : endpoint.name_with_method => endpoint }

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.parent == "root" ? aws_api_gateway_resource.resource[each.value.name].id : aws_api_gateway_resource.child_resource[each.value.name].id
  http_method = each.value.method

  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  for_each = { for endpoint in local.endpoint_list : endpoint.name_with_method => endpoint }

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_method.method[each.value.name_with_method].resource_id
  http_method = aws_api_gateway_method.method[each.value.name_with_method].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  count = length(var.api_stage_name)

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_stage_name[count.index]

  triggers = {
    redeployment = sha1(join(",", tolist(
      [jsonencode(aws_api_gateway_integration.integration[*])],
    )))
  }

  # Force the deployment
  description = "Deployed at ${timestamp()}"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.integration
   ]
}
