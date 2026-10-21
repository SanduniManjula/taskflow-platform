# TaskFlow Platform Engineering Assessment

A Spring Boot task-management API deployed to Amazon ECS on EC2, backed by RDS PostgreSQL, provisioned with Terraform, configured with Ansible, and released using GitLab CI/CD.

> This repository is a reference implementation. Validate all AWS resources, IAM policies, Terraform plans, costs, and GitLab protections in a disposable development account before using it. Do not commit credentials, `.env` files, Terraform state, or plan files.

## Architecture

- Public ALB in two public subnets.
- ECS cluster on EC2 capacity in private subnets across two AZs.
- RDS PostgreSQL in private database subnets.
- ECR image tagged with the commit SHA.
- Secrets Manager for the database password.
- CloudWatch logs and alarms.
- GitLab CI stages for lint, security, test, build, plan, apply, configure, deploy, and smoke test.

## Local prerequisites

Java 21, Maven 3.9+, Docker Compose v2, Git. For AWS deployment also install AWS CLI v2, Terraform (>=1.6), and Ansible with `amazon.aws` collection.

## Run locally

```bash
cd app
mvn test
mvn spring-boot:run
```

Or start PostgreSQL and the application using Compose from the repository root:

```bash
docker compose up --build
curl http://localhost:8080/health
curl http://localhost:8080/v3/api-docs
```

Swagger UI: http://localhost:8080/swagger-ui.html

## API

| Method | Path | Description |
|---|---|---|
| POST | `/api/tasks` | Create a task |
| GET | `/api/tasks` | List tasks |
| GET | `/api/tasks/{id}` | Retrieve one task |
| PUT | `/api/tasks/{id}` | Replace/update a task |
| DELETE | `/api/tasks/{id}` | Delete a task |
| GET | `/health` | Health check |

Example:
```bash
curl -X POST http://localhost:8080/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Prepare platform demo","description":"Demonstrate CRUD","status":"TODO"}'
```

## AWS deployment sequence

1. Create an AWS account for the assessment and set a budget alert.
2. Configure AWS CLI with a dedicated least-privilege deployment identity.
3. Bootstrap Terraform remote state (S3 bucket and lockfile support) separately; see `terraform/bootstrap/README.md`.
4. Configure GitLab CI/CD variables as masked and protected: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_DEFAULT_REGION`. Prefer GitLab OIDC / AWS role assumption where available.
5. Review and adapt `terraform/environments/dev`. Run `terraform init`, `terraform fmt -check`, `terraform validate`, and `terraform plan` locally first.
6. Deploy only after reviewing the plan. Keep EC2 and RDS sizes small for development; NAT gateways and ALBs have ongoing charges.
7. Configure Ansible inventory and verify idempotency.
8. Push to GitLab and use the protected manual apply job.
9. Verify `/health`, CRUD operations, CloudWatch logs, and scaling evidence.
10. Run `terraform destroy` when finished, after confirming no shared resources or data will be removed.

## Important limitations / production hardening

- The Terraform environment is an assessment baseline, not a turnkey production account landing zone. Review account quotas, AMI selection, VPC endpoints/NAT cost, IAM, RDS backup/maintenance settings, and deployment availability before applying.
- The vertical scaling controller must be bounded and protected against repeated scale actions. Do not grant arbitrary Terraform execution to Lambda. This implementation uses a separate scaling function that updates a task definition and deploys a new revision; it is not a Terraform apply. If the assessor interprets the requirement strictly as “scoped Terraform apply,” replace the controller with a protected CI-triggered Terraform workflow and document the trade-off.
- ECS task CPU/memory changes require sufficient EC2 capacity. The EC2 Auto Scaling Group must be able to accommodate the selected task size.
- The application health endpoint checks process health; use a separate readiness/database check if required by your operational policy.
- Run security tools and inspect their findings rather than suppressing them blindly.

## Evidence checklist

- [ ] `mvn test` and JaCoCo coverage report >=70%.
- [ ] `docker compose up --build` and `/health` returns HTTP 200.
- [ ] `terraform fmt -check`, `validate`, and a reviewed plan.
- [ ] Ansible first run changes hosts; second run reports zero changes.
- [ ] MR pipeline has no apply/deploy jobs.
- [ ] Protected default-branch apply requires manual approval.
- [ ] ECR image uses `$CI_COMMIT_SHORT_SHA`.
- [ ] ECS task definition revision changes after vertical scaling.
- [ ] ALB smoke test passes.
- [ ] Runbook, ADR, architecture diagram, and teardown steps are documented.
