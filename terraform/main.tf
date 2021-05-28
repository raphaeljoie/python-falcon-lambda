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


################################################################################
# IAM PERMISSIONS
################################################################################

resource "aws_iam_role" "lambda_role" {
  # Only create a dedicated role if no role arn is provided
  count = var.lambda_iam_role_arn != null ? 0 : 1

  name = var.lambda_iam_role != null ? var.lambda_iam_role : "AWSLambdaVPCAccessExecutionRole-${var.lambda_name}"

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

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  count = var.lambda_iam_role_arn != null ? 0 : 1

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = data.aws_iam_policy.aws_lambda_logs_policy.arn
}

data "aws_iam_policy" "aws_lambda_logs_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_execute" {
  count = var.lambda_iam_role_arn != null ? 0 : 1

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = data.aws_iam_policy.aws_lambda_execute_policy.arn
}

data "aws_iam_policy" "aws_lambda_execute_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}


################################################################################
# LAMBDA FUNCTION
################################################################################

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  # Explicitly create Log group to enforce custom retention time
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

resource "aws_s3_bucket_object" "lambda_version" {
  bucket = var.lambda_bucket_name
  key = "${var.lambda_name}/${var.lambda_version}/${local.zip_filename}"
  source = "${var.lambda_folder}/${local.zip_filename}"
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.lambda_name

  s3_bucket = var.lambda_bucket_name
  s3_key = "${var.lambda_name}/${var.lambda_version}/${local.zip_filename}"

  runtime = var.lambda_runtime
  handler = var.lambda_handler
  timeout = var.lambda_timeout

  role = var.lambda_iam_role_arn != null ? var.lambda_iam_role_arn : aws_iam_role.lambda_role[0].arn

  dynamic "environment" {
    for_each = local.environment_map
    content {
      variables = environment.value
    }
  }

  tags = var.tags

  vpc_config {
    security_group_ids = var.vpc_security_group_ids
    subnet_ids = var.vpc_subnet_ids
  }

  depends_on = [
    # Make sure it can write logs before it starts
    aws_iam_role_policy_attachment.lambda_logs,
    # Make sure the custom log group is created before, or a default retention period is used
    aws_cloudwatch_log_group.lambda_log_group,
    # Make sure the S3 object exists before the creation
    aws_s3_bucket_object.lambda_version
  ]

  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }
}


################################################################################
# API GATEWAY
################################################################################

resource "aws_api_gateway_rest_api" "api" {
  name = var.api_name != null ? var.api_name : "${var.lambda_name}-api"

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
