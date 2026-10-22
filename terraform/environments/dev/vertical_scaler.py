import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs = boto3.client("ecs")
cloudwatch = boto3.client("cloudwatch")

CLUSTER = os.environ["ECS_CLUSTER_NAME"]
SERVICE = os.environ["ECS_SERVICE_NAME"]
HIGH_CPU_ALARM = os.environ["HIGH_CPU_ALARM"]
HIGH_MEMORY_ALARM = os.environ["HIGH_MEMORY_ALARM"]
LOW_CPU_ALARM = os.environ["LOW_CPU_ALARM"]
LOW_MEMORY_ALARM = os.environ["LOW_MEMORY_ALARM"]

SIZES = {
    "small": {"cpu": "256", "memory": "512", "container_cpu": 256,
              "container_memory": 512, "reservation": 256},
    "large": {"cpu": "512", "memory": "1024", "container_cpu": 512,
              "container_memory": 1024, "reservation": 768},
}


def average_metric(metric_name):
    result = cloudwatch.get_metric_statistics(
        Namespace="AWS/ECS",
        MetricName=metric_name,
        Dimensions=[
            {"Name": "ClusterName", "Value": CLUSTER},
            {"Name": "ServiceName", "Value": SERVICE},
        ],
        StartTime=__import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ) - __import__("datetime").timedelta(minutes=10),
        EndTime=__import__("datetime").datetime.now(
            __import__("datetime").timezone.utc),
        Period=300,
        Statistics=["Average"],
    )
    points = result.get("Datapoints", [])
    if not points:
        return None
    return sum(point["Average"] for point in points) / len(points)


def handler(event, context):
    # Support both direct CloudWatch alarm events and EventBridge events.
    alarm_data = event.get("alarmData", {})
    state_data = alarm_data.get("state", {})

    alarm_name = (
        event.get("AlarmName")
        or alarm_data.get("alarmName")
        or ""
    )
    new_state = (
        event.get("NewStateValue")
        or state_data.get("value")
        or ""
    )

    if new_state != "ALARM":
        logger.info("Ignoring non-ALARM event: %s", event)
        return {"status": "ignored", "reason": "alarm state is not ALARM"}

    service = ecs.describe_services(
        cluster=CLUSTER, services=[SERVICE]
    )["services"][0]

    current_task = ecs.describe_task_definition(
        taskDefinition=service["taskDefinition"]
    )["taskDefinition"]

    current_cpu = str(current_task.get("cpu", ""))
    current_memory = str(current_task.get("memory", ""))

    if alarm_name in (HIGH_CPU_ALARM, HIGH_MEMORY_ALARM):
        target = SIZES["large"]
    elif alarm_name in (LOW_CPU_ALARM, LOW_MEMORY_ALARM):
        high_alarms = cloudwatch.describe_alarms(
            AlarmNames=[HIGH_CPU_ALARM, HIGH_MEMORY_ALARM]
        ).get("MetricAlarms", [])

        if (
            len(high_alarms) != 2
            or any(alarm.get("StateValue") != "OK" for alarm in high_alarms)
        ):
            logger.info("Scale-down skipped: high alarms are not both OK")
            return {
                "status": "no-change",
                "reason": "high CPU and memory alarms must both be OK",
            }

        cpu = average_metric("CPUUtilization")
        memory = average_metric("MemoryUtilization")
        logger.info("Recent averages: CPU=%s Memory=%s", cpu, memory)

        if cpu is None or memory is None or cpu >= 30 or memory >= 30:
            return {
                "status": "no-change",
                "reason": "both CPU and memory are not confirmed below 30%",
            }
        target = SIZES["small"]
    else:
        logger.warning("Unknown alarm: %s", alarm_name)
        return {"status": "ignored", "reason": "unknown alarm"}

    if (current_cpu == target["cpu"]
            and current_memory == target["memory"]):
        logger.info("Task definition is already at target size")
        return {"status": "no-change", "reason": "already at target size"}

    allowed_fields = [
        "family", "taskRoleArn", "executionRoleArn", "networkMode",
        "containerDefinitions", "volumes", "placementConstraints",
        "requiresCompatibilities", "cpu", "memory", "tags", "pidMode",
        "ipcMode", "proxyConfiguration", "inferenceAccelerators",
        "ephemeralStorage", "runtimePlatform",
    ]
    registration = {
        key: current_task[key]
        for key in allowed_fields
        if key in current_task
    }

    registration["cpu"] = target["cpu"]
    registration["memory"] = target["memory"]

    containers = []
    for original in registration["containerDefinitions"]:
        container = dict(original)
        if container.get("name") == "taskflow":
            container["cpu"] = target["container_cpu"]
            container["memory"] = target["container_memory"]
            container["memoryReservation"] = target["reservation"]
        containers.append(container)

    registration["containerDefinitions"] = containers

    new_task = ecs.register_task_definition(**registration)["taskDefinition"]
    ecs.update_service(
        cluster=CLUSTER,
        service=SERVICE,
        taskDefinition=new_task["taskDefinitionArn"],
    )

    logger.info(
        "Vertical scaling requested: alarm=%s task=%s cpu=%s memory=%s",
        alarm_name,
        new_task["taskDefinitionArn"],
        target["cpu"],
        target["memory"],
    )

    return {
        "status": "updated",
        "taskDefinition": new_task["taskDefinitionArn"],
        "cpu": target["cpu"],
        "memory": target["memory"],
    }
