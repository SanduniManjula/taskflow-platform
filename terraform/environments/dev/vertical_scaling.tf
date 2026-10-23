data "archive_file" "vertical_scaler" {
  type        = "zip"
  source_file = "${path.module}/vertical_scaler.py"
  output_path = "${path.module}/vertical_scaler.zip"
}

resource "aws_iam_role" "vertical_scaler" {
  name = "${local.name}-vertical-scaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vertical_scaler_logs" {
  role       = aws_iam_role.vertical_scaler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "vertical_scaler_ecs" {
  name = "${local.name}-vertical-scaling"
  role = aws_iam_role.vertical_scaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ecs:RegisterTaskDefinition"]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${aws_ecs_task_definition.app.family}:*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:GetMetricStatistics"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["cloudwatch:DescribeAlarms"]
        Resource = [
          "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name}-high-cpu",
          "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name}-high-memory",
          "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name}-low-cpu",
          "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name}-low-memory"
        ]
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.execution.arn,
          aws_iam_role.task.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}


resource "aws_sqs_queue" "vertical_scaler_dlq" {
  name                    = "${local.name}-vertical-scaler-dlq"
  sqs_managed_sse_enabled = true
}

resource "aws_iam_role_policy" "vertical_scaler_dlq" {
  name = "${local.name}-vertical-scaler-dlq"
  role = aws_iam_role.vertical_scaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.vertical_scaler_dlq.arn
    }]
  })
}

resource "aws_lambda_function" "vertical_scaler" {
  function_name                  = "${local.name}-vertical-scaler"
  description                    = "Bounded ECS task vertical scaling for TaskFlow"
  role                           = aws_iam_role.vertical_scaler.arn
  handler                        = "vertical_scaler.handler"
  runtime                        = "python3.12"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 5

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.vertical_scaler_dlq.arn
  }

  filename         = data.archive_file.vertical_scaler.output_path
  source_code_hash = data.archive_file.vertical_scaler.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_NAME  = aws_ecs_cluster.main.name
      ECS_SERVICE_NAME  = aws_ecs_service.app.name
      HIGH_CPU_ALARM    = "${local.name}-high-cpu"
      HIGH_MEMORY_ALARM = "${local.name}-high-memory"
      LOW_CPU_ALARM     = "${local.name}-low-cpu"
      LOW_MEMORY_ALARM  = "${local.name}-low-memory"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.vertical_scaler_logs,
    aws_iam_role_policy.vertical_scaler_ecs,
    aws_iam_role_policy.vertical_scaler_dlq
  ]
}

resource "aws_lambda_permission" "high_cpu" {
  statement_id  = "AllowHighCpuAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vertical_scaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.cpu.arn
}

resource "aws_lambda_permission" "high_memory" {
  statement_id  = "AllowHighMemoryAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vertical_scaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.memory.arn
}

resource "aws_lambda_permission" "low_cpu" {
  statement_id  = "AllowLowCpuAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vertical_scaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.low_cpu.arn
}

resource "aws_lambda_permission" "low_memory" {
  statement_id  = "AllowLowMemoryAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vertical_scaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.low_memory.arn
}
