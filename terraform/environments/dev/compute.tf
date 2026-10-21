# ECS-optimized AL2023 AMI and launch template.
resource "aws_launch_template" "ecs" {
  name_prefix   = "${local.name}-ecs-"
  image_id      = data.aws_ami.ecs.id
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.ecs.id]

  user_data = base64encode(<<-EOFUSER
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    dnf install -y amazon-cloudwatch-agent
    EOFUSER
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name           = "${local.name}-ecs-host"
      AnsibleManaged = "true"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${local.name}-ecs-asg"
  min_size            = 2
  desired_capacity    = var.desired_ec2_capacity
  max_size            = var.max_ec2_capacity
  vpc_zone_identifier = module.network.private_subnet_ids

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-ecs-host"
    propagate_at_launch = true
  }

  tag {
    key                 = "AnsibleManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "${local.name}-ec2-capacity"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }

    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name              = "taskflow"
    image             = "${aws_ecr_repository.app.repository_url}:${var.app_image_tag}"
    essential         = true
    cpu               = var.container_cpu
    memory            = var.container_memory
    memoryReservation = min(256, var.container_memory)

    portMappings = [{
      containerPort = var.app_port
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = tostring(var.app_port) },
      { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/${var.db_name}" },
      { name = "SPRING_DATASOURCE_USERNAME", value = var.db_username },
      { name = "DDL_AUTO", value = "update" }
    ]

    secrets = [{
      name      = "SPRING_DATASOURCE_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.db.arn}:password::"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "task"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -q -O - http://localhost:8080/health >/dev/null || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  depends_on = [aws_secretsmanager_secret_version.db]
}

resource "aws_ecs_service" "app" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "taskflow"
    container_port   = var.app_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main
  ]
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 65

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 180
    scale_out_cooldown = 60
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name  = "${local.name}-high-cpu"
  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_description   = "Sustained high ECS service CPU; use the bounded vertical-scaling workflow."
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name  = "${local.name}-high-memory"
  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_description   = "Sustained high ECS service memory; use the bounded vertical-scaling workflow."
}
