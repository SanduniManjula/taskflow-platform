# ADR-001: Use Amazon ECS on EC2 rather than Fargate

- Status: Accepted for this assessment
- Decision: Run ECS tasks on an EC2 Auto Scaling Group using ECS-optimized instances.
- Context: The assessment explicitly requires EC2 hosts that Ansible can discover and configure, including the ECS agent, CloudWatch agent, and baseline OS hardening.
- Consequences: The team controls host configuration and capacity, but must patch instances, secure SSH, maintain the ASG, and ensure sufficient capacity for task CPU/memory profiles. Fargate would reduce host operations but would not satisfy the real-host Ansible requirement.
- Guardrails: Instances stay in private subnets; use SSM where possible; no public SSH ingress; use a launch template and rolling instance replacement; monitor cluster capacity.
