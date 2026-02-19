# Lambda Function - Appointment Store
# Automatiza el deployment de Lambda + API Gateway

# Variables
variable "db_host" {
  description = "RDS endpoint"
  type        = string
  default     = "ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com"
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_appointment_store_role" {
  name = "ocai-appointment-store-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "OCAI Appointment Store Lambda Role"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Attach policy para CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_appointment_store_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach policy para VPC (si Lambda está en VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_appointment_store_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "appointment_store" {
  filename         = "../aws_lambdas/lambda_appointment_store.zip"
  function_name    = "ocai-appointment-store"
  role            = aws_iam_role.lambda_appointment_store_role.arn
  handler         = "lambda_appointment_store.lambda_handler"
  runtime         = var.lambda_runtime
  timeout         = 30
  memory_size     = 256
  source_code_hash = filebase64sha256("../aws_lambdas/lambda_appointment_store.zip")

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = "5432"
      DB_NAME     = "n8n_db"
      DB_USER     = "postgres"
      DB_PASSWORD = var.db_password
    }
  }

  # Descomentar si Lambda necesita estar en VPC
  # vpc_config {
  #   subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  #   security_group_ids = [aws_security_group.lambda_sg.id]
  # }

  tags = {
    Name        = "OCAI Appointment Store"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.appointment_store.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "OCAI Appointment Store Logs"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "appointment_api" {
  name          = "ocai-appointment-api"
  protocol_type = "HTTP"
  description   = "API Gateway for OCAI Appointment Service"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name        = "OCAI Appointment API"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# API Gateway Integration con Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.appointment_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.appointment_store.invoke_arn

  payload_format_version = "2.0"
}

# API Gateway Route - POST
resource "aws_apigatewayv2_route" "appointment_post" {
  api_id    = aws_apigatewayv2_api.appointment_api.id
  route_key = "POST /appointment/create"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Route - OPTIONS (CORS preflight)
resource "aws_apigatewayv2_route" "appointment_options" {
  api_id    = aws_apigatewayv2_api.appointment_api.id
  route_key = "OPTIONS /appointment/create"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.appointment_api.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name        = "OCAI Appointment API - Production"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/apigateway/ocai-appointment-api"
  retention_in_days = 7

  tags = {
    Name        = "OCAI Appointment API Logs"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Permiso para API Gateway invocar Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.appointment_store.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.appointment_api.execution_arn}/*/*"
}

# Outputs
output "lambda_function_arn" {
  description = "ARN de la Lambda function"
  value       = aws_lambda_function.appointment_store.arn
}

output "lambda_function_name" {
  description = "Nombre de la Lambda function"
  value       = aws_lambda_function.appointment_store.function_name
}

output "api_gateway_endpoint" {
  description = "Endpoint de API Gateway"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/appointment/create"
}

output "api_gateway_id" {
  description = "ID del API Gateway"
  value       = aws_apigatewayv2_api.appointment_api.id
}
