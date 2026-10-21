# Deployment and Operations Runbook

## Release
1. Open a merge request. Confirm lint, security, tests, coverage, image build and Terraform plan pass.
2. Review the plan artifact and security findings.
3. Merge to the protected default branch.
4. Approve the manual apply job only after checking the plan and target AWS account/region.
5. Confirm Ansible configuration, ECS service stability, and the ALB smoke test.
6. Confirm the deployed image tag equals the commit SHA.

## Troubleshooting
- ALB returns 503: check target group health, ECS service events, security group paths, container port 8080 and `/health`.
- Tasks fail to start: inspect ECS service events, task stopped reason, CloudWatch logs, image URI and task execution role permissions.
- Database connection errors: check RDS security group source (ECS task/instance security group), subnet routes, database secret ARN, username/password rotation and JDBC URL.
- No ECS capacity: check ASG desired/max size, EC2 launch template, cluster registration, task placement constraints and CPU/memory reservation.
- CI AWS authentication fails: confirm protected variables are available only to protected refs, region and IAM permissions.

## Scaling
- Horizontal scaling changes task count when average service CPU/memory stays above/below the target. It helps concurrency and throughput when tasks fit the current instance capacity.
- Vertical scaling changes each task's CPU/memory profile and requires a new task definition revision and deployment. Use it when one task needs more memory/CPU. Ensure EC2 capacity can place the larger task.
- Use sustained alarms, cooldowns, bounded profiles and an audit trail. Never allow alarms to repeatedly increase resources without a ceiling.

## Rollback
Deploy the last known-good immutable image tag and task definition revision through the controlled pipeline. Do not edit the task definition manually in the console as the normal release path.

## Teardown
Review the Terraform destroy plan carefully. Back up any required data, remove test resources only, and verify ECR images, RDS snapshots, NAT gateways and load balancers that may continue incurring charges.
