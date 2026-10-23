# TaskFlow Assessment Evidence Index

This index records verification results and the supporting screenshots.
A screenshot's existence does not, by itself, prove that the feature passed.

Evidence location on Windows:
`C:\Users\User\OneDrive\Documents\TaskFlow-Evidence\`

## Verified results

| Requirement | Verification result | Status |
|---|---|---|
| Application tests | `mvn verify` passed; 23 tests passed | Verified |
| JaCoCo line coverage | 88.41% (61 covered of 69 lines) | Verified |
| Terraform validation | `terraform validate` succeeded | Verified |
| Deployed API health | ALB `/health` returned HTTP 200 | Verified |
| Ansible connectivity | Playbook ran against all three EC2 instances | Verified |
| Ansible idempotency | Second run reported zero changes | Verified |
| CloudWatch logging | ECS agent events were received from EC2 instances | Verified |
| Terraform outputs | Outputs identified deployed infrastructure resources | Verified |
| GitLab deployment jobs | Terraform apply, ECS deployment, and smoke-test jobs passed | Verified |
| CI/CD screenshots | Evidence screenshots were added to the repository | Verify image contents before submission |

## Screenshot inventory

### Application

- `Application/taskflow-application-health.png`
- `Application/taskflow-swagger-ui.png`

### AWS deployment

- `AWS-Deployment/taskflow-cloudwatch-logs1.png`
- `AWS-Deployment/taskflow-cloudwatch-logs2.png`
- `AWS-Deployment/taskflow-ecs-deployment.png`

### Terraform and Ansible

- `Terraform-Ansible/taskflow-ansible-connectivity.png`
- `Terraform-Ansible/taskflow-ansible-first-run.png`
- `Terraform-Ansible/taskflow-ansible-final-idempotency.png`
- `Terraform-Ansible/taskflow-ansible-idempotency-check.png`
- `Terraform-Ansible/taskflow-ansible-idempotency-passed1.png`
- `Terraform-Ansible/taskflow-ansible-idempotency-passed2.png`
- `Terraform-Ansible/taskflow-ansible-syntax-check.png`
- `Terraform-Ansible/taskflow-asg-capacity-healthy.png`
- `Terraform-Ansible/taskflow-cloudwatch-idempotency-diagnostic.png`
- `Terraform-Ansible/taskflow-ec2-cloudwatch-log-events.png`
- `Terraform-Ansible/taskflow-ec2-cloudwatch-logs.png`
- `Terraform-Ansible/taskflow-terraform-outputs.png`
- `Terraform-Ansible/taskflow-terraform-validate2.png`
- `Terraform-Ansible/taskflow-terraform-validation.png`

### Scaling

- `Scaling/taskflow-lambda-scaling-success.png`
- `Scaling/taskflow-scaling-after.png`
- `Scaling/taskflow-scaling-before.png`

### Test results

- `Test-Results/taskflow-alb-health-check.png`
- `Test-Results/taskflow-alb-health-check2.png`
- `Test-Results/taskflow-github-actions-no-workflows.png`
- `Test-Results/taskflow-maven-test-results1.png`
- `Test-Results/taskflow-maven-test-results2.png`

## Still requiring verification

- A fully successful GitLab pipeline, including review and resolution of the failing `secret-scan` job.
- GitLab merge-request approvals, protected-branch settings, and pipeline rules.
- Docker Compose startup and application/database health.
- ECR image tagging with the commit SHA and confirmation that the running ECS task uses the intended image.
- A real CloudWatch alarm transition and confirmation that it triggers the intended vertical-scaling action.
- End-to-end CRUD operations against the deployed environment.
- Security scan findings, remediation, and any remaining unresolved issues.
- Review of screenshot contents for clarity, accuracy, and suitability before submission.
- Confirmation that the architecture documentation and evidence index are complete and committed.

## Infrastructure caution

The live Auto Scaling Group has desired capacity 3, while the current Terraform plan proposes reducing it to 2.

Do not apply this plan without reviewing the impact and obtaining explicit approval. Reducing capacity may terminate an EC2 instance.

Preserve required evidence and Terraform state until the assessment is complete. Do not tear down AWS resources until teardown is explicitly approved.
