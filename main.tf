provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "TestCollection2" {
    name = "TestCollection"
    billing_mode = "PROVISIONED"
    read_capacity  = 10
    write_capacity = 10
    hash_key = "word"
    attribute {
      name = "word"
      type = "S"
    }
}

resource "aws_dynamodb_table_item" "items" {
    table_name = aws_dynamodb_table.TestCollection2.name
    hash_key = aws_dynamodb_table.TestCollection2.hash_key
    
    item = <<ITEM
    {
        "word": {"S": "Car"},
        "word": {"S": "Truck"},
        "word": {"S": "Banana"}
    }
    ITEM
}

data "archive_file" "lambda-zip" {
    type = "zip"
    source_dir = "lambda"
    output_path = "lambda.zip"
}

resource "aws_iam_role" "lambda-iam" {
    name = "lambda-iam"
    assume_role_policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts.Assumerole",
            "Principal": {
                "Service": ["lambda.amazonaws.com"]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}

    EOF
}

resource "aws_lambda_function" "Connect1" {
    filename = "lambda.zip"
    function_name = "Connect1"
    role = aws_iam_role.lambda-iam.arn
    handler = "lambda.lambda_handler"
    source_code_hash = data.archive_file.lambda-zip.output_base64sha256
    runtime = "python3.9"
}

resource "aws_lambda_function" "Disconnect1" {
    filename = "lambda.zip"
    function_name = "Disconnect1"
    role = aws_iam_role.lambda-iam.arn
    handler = "lambda.lambda_handler"
    source_code_hash = data.archive_file.lambda-zip.output_base64sha256
    runtime = "python3.9"
}

resource "aws_lambda_function" "getWords1" {
    filename = "lambda.zip"
    function_name = "getWords1"
    role = aws_iam_role.lambda-iam.arn
    handler = "lambda.lambda_handler"
    source_code_hash = data.archive_file.lambda-zip.output_base64sha256
    runtime = "python3.7"
}

resource "aws_apigatewayv2_api" "TestAPI1" {
    name = "TestAPI-websocket-api"
    protocol_type = "WEBSOCKET"
    route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_stage" "production" {
    api_id = aws_apigatewayv2_api.TestAPI1.id
    name = "$default"
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "Connect-integration" {
    api_id = aws_apigatewayv2_api.TestAPI1.id
    integration_type = "AWS_PROXY"
    integration_method = "POST"
    integration_uri = aws_lambda_function.Connect1.invoke_arn
    passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_integration" "Disconnect-integration" {
    api_id = aws_apigatewayv2_api.TestAPI1.id
    integration_type = "AWS_PROXY"
    integration_method = "POST"
    integration_uri = aws_lambda_function.Disconnect1.invoke_arn
    passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_integration" "SendMessage-integration" {
    api_id = aws_apigatewayv2_api.TestAPI1.id
    integration_type = "AWS_PROXY"
    integration_method = "POST"
    integration_uri = aws_lambda_function.getWords1.invoke_arn
    passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "SendMessage" {
    api_id = aws_apigatewayv2_api.TestAPI1.id
    route_key = "GET /{proxy+}"
    target = "integrations/${aws_apigatewayv2_integration.SendMessage-integration.id}"
}

resource "aws_lambda_permission" "api-gw" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.getWords1.arn
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.TestAPI1.execution_arn}/*/*/*"
}
