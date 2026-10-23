# TaskFlow Platform Engineering Assessment

A Spring Boot task-management API deployed to Amazon ECS on EC2, backed by RDS PostgreSQL, provisioned with Terraform, configured with Ansible, and released using GitLab CI/CD.

> This repository is a reference implementation. Validate all AWS resources, IAM policies, Terraform plans, costs, and GitLab protections in a disposable development account before using it. Do not commit credentials, `.env` files, Terraform state, or plan files.

## Architecture

See [the TaskFlow architecture diagram](docs/architecture/taskflow-architecture.md).

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

### Verified

- [x] Maven tests pass and a JaCoCo coverage report was generated.
- [x] JaCoCo line coverage is 88.41% (61 covered of 69 total lines; required >=70%).
- [x] Terraform validation passes.
- [x] Ansible configuration runs successfully against all three EC2 instances.
- [x] Ansible second run reports zero changes.
- [x] CloudWatch receives ECS agent logs from the EC2 instances.
- [x] Deployed ALB `/health` endpoint returns HTTP 200.
- [x] Terraform outputs identify the deployed infrastructure resources.

### Configured or not yet fully verified

- [ ] Verify Docker Compose starts the application and database successfully.
- [ ] Verify a successful GitLab CI/CD pipeline run.
- [ ] Verify merge-request and protected-branch rules in GitLab.
- [ ] Verify ECR image tagging with `$CI_COMMIT_SHORT_SHA`.
- [ ] Verify a real CloudWatch alarm transition triggers vertical scaling.
- [ ] Verify end-to-end CRUD operations against the deployed environment.
- [x] Add an architecture diagram at `docs/architecture/taskflow-architecture.md`.
- [x] Add the screenshot inventory and verification status at `docs/evidence-index.md`.

### Operational review

- [x] Document the ASG capacity difference: live desired capacity is 3, while the Terraform plan proposes 2.
- [ ] Review the Terraform plan for unintended changes before any apply.
- [ ] Review security scan findings and document unresolved issues.
- [ ] Confirm teardown steps preserve required evidence, data, and Terraform state.

## DevOps vs. Platform Engineering

DevOps is a culture and set of practices that brings software development and IT operations together. It emphasizes collaboration, automation, continuous integration, continuous delivery, testing, monitoring, and shared responsibility for software reliability.

Platform Engineering builds on these practices by creating reusable infrastructure, tools, workflows, and self-service capabilities for development teams. Instead of every team independently configuring infrastructure and deployment pipelines, a platform team provides standardized solutions that improve consistency and developer productivity.

This TaskFlow project demonstrates DevOps through automated application testing, Docker image builds, infrastructure validation, deployment, and health checks. It demonstrates Platform Engineering principles through reusable Terraform infrastructure, Ansible configuration management, and a standardized GitLab CI/CD workflow. These foundations can be extended into an internal developer platform with self-service provisioning, reusable templates, and centralized policy enforcement.

## The Shift Toward DevSecOps

DevSecOps integrates security into every stage of the software delivery lifecycle. Cloud infrastructure, container images, application dependencies, APIs, and CI/CD credentials can all introduce security risks. Detecting problems only before release can increase remediation costs and delay deployments.

DevSecOps addresses these challenges by automating security checks early and continuously, while making security a shared responsibility among development, operations, platform engineering, and security teams.

In TaskFlow, the pipeline includes secret scanning, Terraform security checks, container image scanning, automated tests, and controlled CI/CD variables. These practices help identify potential risks before deployment and improve visibility into security issues.

Security tools do not guarantee that an application is secure. Scan results must be reviewed, false positives investigated, and unresolved findings assessed before release. Credentials must never be committed to source control, and deployment permissions should follow the principle of least privilege.

## Reproducing the Deployment from a Clean AWS Account

The following process summarizes how to reproduce the deployment in a newly prepared AWS account. Exact Terraform paths, variable names, and commands must match the configuration in this repository.

1. Prepare the AWS account, configure billing alerts and security controls, and select the intended region.
2. Configure AWS CLI authentication using a dedicated IAM role or another approved credential mechanism. Verify the identity with `aws sts get-caller-identity`.
3. Review the Terraform configuration and bootstrap the remote state backend, if required, before initializing the main environment.
4. Configure the necessary Terraform variables and GitLab CI/CD variables. Never commit AWS credentials, passwords, `.env` files, Terraform state, or plan files.
5. Run `terraform init`, `terraform fmt -check`, `terraform validate`, and `terraform plan` from the correct Terraform environment directory. Review the plan before applying changes.
6. Build the application container and publish a commit-versioned image to Amazon ECR through the configured pipeline.
7. Apply the approved infrastructure changes using the project's deployment procedure.
8. Run the Ansible playbook against the intended EC2 hosts and verify that a second run produces no unexpected changes.
9. Deploy the intended image revision to the ECS service through GitLab CI/CD.
10. Verify ECS task health, load balancer target health, the application health endpoint, CloudWatch logs, and application functionality.
11. Review security scan results and scaling evidence. When the environment is no longer needed, review the Terraform destroy plan and remove temporary resources without deleting shared resources or required evidence.

AWS resources such as EC2 instances, RDS databases, NAT gateways, and load balancers may incur charges. Review resource costs before deployment and teardown. A successful Terraform plan does not prove that the application is running; verify the actual deployment and its health.

