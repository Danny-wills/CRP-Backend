terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"

    }
  }
}

# Configure the AWS Provider
provider "aws" {
  profile = "iamadmin-general"
  region  = "us-east-1"
  alias   = "us-east-1"
}


# ------------------ dynamodb ------------------- #
# Create a table and input default values
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "visitor_counter"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "visitors"

  attribute {
    name = "visitors"
    type = "S"
  }


}

resource "aws_dynamodb_table_item" "put_item_visits" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "visitors": {"S": "visits"},
  "visits": {"N": "0"}
}
ITEM

  lifecycle {
    ignore_changes = all
  }
}

# ------------------- lambda function --------------- #
# Using the assume role policy from above, create a role for lambda
resource "aws_iam_role" "role_iam_for_lambda" {
  name               = "role_iam_for_lambda"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }]
}
EOF
}
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.role_iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Po;icy to allow lambda access dynamodb
resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
  name = "dynamodb_lambda_policy"
  role = aws_iam_role.role_iam_for_lambda.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["dynamodb:*"],
        "Resource" : "${aws_dynamodb_table.visitor_counter.arn}"
      }
    ]
  })
}

# Compress python file for lambda into zip
data "archive_file" "zip" {
  type        = "zip"
  source_file = "Backend/function/lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "counter_function" {
  function_name    = "counter_function"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  role             = aws_iam_role.role_iam_for_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter_function.function_name
  principal     = "apigateway.amazonaws.com"
}

# -------------------- api gateway ------------------- #
resource "aws_api_gateway_rest_api" "counter" {
  name = "visitors_counter_api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "count" {
  rest_api_id = aws_api_gateway_rest_api.counter.id
  parent_id   = aws_api_gateway_rest_api.counter.root_resource_id
  path_part   = "count"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id      = aws_api_gateway_rest_api.counter.id
  resource_id      = aws_api_gateway_resource.count.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.counter.id
  resource_id             = aws_api_gateway_resource.count.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.counter_function.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.counter.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.counter.body))
  }

  depends_on = [
    aws_api_gateway_integration.integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.counter.id
  stage_name    = "prod"
}

output "invoke_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.stage.stage_name}/${aws_api_gateway_resource.count.path_part}"
}