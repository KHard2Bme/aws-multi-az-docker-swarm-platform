# AWS Multi-AZ Docker Swarm Platform

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)](https://www.docker.com/)
[![Amazon Linux 2023](https://img.shields.io/badge/OS-Amazon%20Linux%202023-FF9900?logo=amazonaws)](https://aws.amazon.com/linux/amazon-linux-2023/)
[![CloudWatch](https://img.shields.io/badge/Monitoring-CloudWatch-FF4F8B?logo=amazonaws)](https://aws.amazon.com/cloudwatch/)

> A highly available, multi-AZ Docker Swarm platform on AWS designed to demonstrate infrastructure resilience, workload recovery, monitoring, alerting, and controlled failure testing.

## Overview

This project deploys a Docker Swarm platform across three Availability Zones in AWS. The architecture separates the control plane from application workloads and uses three manager nodes and three worker nodes.

The Apache application is deployed as three independent Swarm services:

- `apache-a` → pinned to the worker in `us-east-1a`
- `apache-b` → pinned to the worker in `us-east-1b`
- `apache-c` → pinned to the worker in `us-east-1c`

An Application Load Balancer distributes traffic across the application platform. CloudWatch collects custom host metrics and Docker event logs, while metric filters, alarms, and SNS notifications support failure detection.

## Project Goals

- Build infrastructure across three AWS Availability Zones.
- Create a resilient Docker Swarm control plane.
- Separate manager responsibilities from application workloads.
- Deploy application capacity across three worker nodes.
- Use Terraform for repeatable infrastructure provisioning.
- Collect CloudWatch metrics and Docker event logs.
- Detect container, worker, manager, and ALB health failures.
- Generate CloudWatch alarms and SNS notifications.
- Perform controlled failure and recovery testing.
- Document operational maintenance and recovery procedures.

## Current Architecture

```text
                              Internet
                                 |
                                 v
                    +--------------------------+
                    | Application Load Balancer |
                    +--------------------------+
                         /        |        \
                        /         |         \
                       v          v          v
             +-----------+  +-----------+  +-----------+
             | Worker A  |  | Worker B  |  | Worker C  |
             | us-east-1a|  | us-east-1b|  | us-east-1c|
             | apache-a  |  | apache-b  |  | apache-c  |
             +-----------+  +-----------+  +-----------+

                    Docker Swarm Control Plane
              +-------------+-------------+-------------+
              | Manager 1   | Manager 2   | Manager 3   |
              | us-east-1a  | us-east-1b  | us-east-1c  |
              | Leader      | Reachable   | Reachable   |
              +-------------+-------------+-------------+

                        Monitoring & Alerting
              +-----------------------------------------+
              | CloudWatch Dashboard                    |
              | Docker Event Logs                       |
              | Custom Metrics                          |
              | Metric Filters                          |
              | CloudWatch Alarms                       |
              +-------------------+---------------------+
                                  |
                                  v
                              Amazon SNS
                                  |
                                  v
                             Email Alert
```

## Architecture Components

### Infrastructure

- Custom VPC: `10.0.0.0/16`
- Public subnets across three Availability Zones
- Private subnets across three Availability Zones
- NAT Gateway for private instance outbound access
- Security groups for ALB, Swarm, SSH/administration, and monitoring traffic

### Docker Swarm

**Managers**
- Manager1
- Manager2
- Manager3

The managers provide Docker Swarm quorum and control-plane availability. They are configured with `Drain` availability to prevent normal application workloads from running on the control plane.

**Workers**
- Worker A — `us-east-1a`
- Worker B — `us-east-1b`
- Worker C — `us-east-1c`

Workers are labeled for workload placement:

```text
role=worker
workload=application
az=us-east-1a | us-east-1b | us-east-1c
```

## Application Deployment

The Apache application uses the image:

```text
kevd637/apache-website:v1
```

The application is deployed as three services, each constrained to a specific Availability Zone worker.

Expected service state:

```text
engineering-for-failure_apache-a   1/1
engineering-for-failure_apache-b   1/1
engineering-for-failure_apache-c   1/1
```

Verify:

```bash
sudo docker service ls
```

Inspect placement:

```bash
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ps engineering-for-failure_apache-b
sudo docker service ps engineering-for-failure_apache-c
```

## CloudWatch Monitoring

The Amazon CloudWatch Agent is installed on the worker nodes.

### Custom Namespace

```text
EngineeringForFailure
```

### Custom Metrics

- `cpu_usage_idle`
- `cpu_usage_user`
- `cpu_usage_system`
- `mem_used_percent`
- `bytes_sent`
- `bytes_recv`

### Docker Event Logging

Docker events are collected in:

```text
/var/log/docker-events.log
```

CloudWatch Log Group:

```text
/engineering-for-failure/docker
```

The Docker event monitor runs as:

```text
docker-event-monitor.service
```

Verify:

```bash
sudo systemctl status docker-event-monitor --no-pager
sudo tail -f /var/log/docker-events.log
```

### CloudWatch Agent

Verify:

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
sudo systemctl is-active amazon-cloudwatch-agent
```

The active generated configuration is located under:

```text
/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/
```

## Failure Monitoring

The focused CloudWatch dashboard contains eight widgets:

### Infrastructure

1. Manager CPU Utilization
2. Manager Status Checks

### Worker Monitoring

3. Worker CPU Usage

### Failure Monitoring

4. Container Failures
5. Worker Node Failures
6. Manager Node Failures

### Application Load Balancer

7. ALB Healthy Hosts
8. ALB Unhealthy Hosts

## CloudWatch Alarms

The project includes alarms for:

- Container failures
- Worker node failures
- Manager node failures
- ALB unhealthy hosts

All alarms are configured to publish notifications through an SNS topic after the email subscription is confirmed.

## Baseline Validation

Before failure testing, verify the following.

### 1. Docker Swarm Health

```bash
sudo docker node ls
```

Expected:
- 3 managers are `Ready`
- 3 workers are `Ready`
- one manager is `Leader`
- managers are `Drain`
- workers are `Active`

### 2. Application Services

```bash
sudo docker service ls
```

Expected:

```text
apache-a   1/1
apache-b   1/1
apache-c   1/1
```

### 3. Application Placement

```bash
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ps engineering-for-failure_apache-b
sudo docker service ps engineering-for-failure_apache-c
```

### 4. ALB Target Health

Verify all registered application targets are healthy.

### 5. HTTP Validation

```bash
curl -I http://<ALB-DNS-NAME>
```

Expected:

```text
HTTP/1.1 200 OK
```

### 6. CloudWatch Agent

```bash
sudo systemctl is-active amazon-cloudwatch-agent
```

Expected:

```text
active
```

### 7. Docker Event Monitor

```bash
sudo systemctl is-active docker-event-monitor
```

Expected:

```text
active
```

### 8. CloudWatch Metrics and Logs

Verify:
- custom metrics are appearing in `EngineeringForFailure`
- Docker event entries are appearing in `/engineering-for-failure/docker`
- all four CloudWatch alarms are in `OK` state

## Failure Testing Scenarios

> Perform controlled tests one scenario at a time and confirm recovery before moving to the next test.

### Scenario 1: Container Failure

Force a container/service task to stop and observe:

- Docker event logging
- Container failure metric
- CloudWatch alarm
- SNS notification
- Swarm task recovery

Example:

```bash
sudo docker ps
sudo docker stop <CONTAINER_ID>
```

Recovery verification:

```bash
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ps engineering-for-failure_apache-b
sudo docker service ps engineering-for-failure_apache-c
```

### Scenario 2: Worker Failure

Simulate worker loss using a controlled method appropriate to the test plan, then observe:

- worker node status
- application task behavior
- Docker events
- Worker Node Failure metric
- CloudWatch alarm
- SNS notification
- ALB target health

Recovery validation:

```bash
sudo docker node ls
sudo docker service ls
```

### Scenario 3: Manager Failure

Test manager resilience while preserving quorum.

Observe:

- leader election behavior
- manager status
- Manager Node Failure metric
- CloudWatch alarm
- SNS notification

Important: never intentionally take down enough managers to lose Swarm quorum during a normal resilience test.

### Scenario 4: ALB Unhealthy Target

Create a controlled application/target failure and observe:

- `UnHealthyHostCount`
- ALB target health
- CloudWatch alarm
- SNS notification
- recovery after the target becomes healthy again

## Operational Maintenance Scenarios

### Check Swarm Health

```bash
sudo docker node ls
sudo docker service ls
```

### Check Service Task History

```bash
sudo docker service ps <SERVICE_NAME>
```

### Check Worker Labels

```bash
sudo docker node inspect <NODE_NAME> \
  --format '{{json .Spec.Labels}}'
```

### Check CloudWatch Agent

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

### Restart CloudWatch Agent

```bash
sudo systemctl restart amazon-cloudwatch-agent
```

### Check Docker Event Monitor

```bash
sudo systemctl status docker-event-monitor --no-pager
```

### Restart Docker Event Monitor

```bash
sudo systemctl restart docker-event-monitor
```

### Review Docker Events

```bash
sudo tail -n 100 /var/log/docker-events.log
```

### Redeploy the Stack

From Manager1:

```bash
sudo docker stack deploy -c docker-stack.yml engineering-for-failure
```

Verify:

```bash
sudo docker service ls
sudo docker node ls
```

## Repository Structure

```text
aws-multi-az-docker-swarm-platform/
│
├── main.tf
├── iam.tf
├── cloudwatch.tf
├── alarms.tf
├── variables.tf
├── outputs.tf
├── providers.tf
│
├── docker-stack.yml
│
├── scripts/
│   ├── manager-bootstrap.sh
│   ├── worker-bootstrap.sh
│   └── docker_event_monitor.sh
│
├── docs/
│   ├── architecture/
│   ├── failure-testing/
│   └── screenshots/
│
└── README.md
```

> Adjust this tree to match the exact folders and filenames in the repository.

## Terraform Deployment

Initialize:

```bash
terraform init
```

Validate:

```bash
terraform validate
```

Review:

```bash
terraform plan
```

Deploy:

```bash
terraform apply
```

## Key Lessons Demonstrated

This project demonstrates several practical DevOps and cloud engineering concepts:

- Infrastructure as Code with Terraform
- Multi-AZ architecture
- Docker Swarm quorum and control-plane design
- Application workload isolation
- Service placement constraints
- Automated instance bootstrapping
- AWS Systems Manager Parameter Store
- CloudWatch Agent configuration
- Custom metrics and log collection
- Metric filters and alarms
- SNS-based alerting
- Application Load Balancer health monitoring
- Failure detection and recovery validation

## Final Validation State

A successful baseline should demonstrate:

- 3 Docker Swarm managers available
- 3 Docker Swarm workers available
- manager quorum intact
- application services running across all three AZs
- ALB targets healthy
- HTTP `200 OK`
- CloudWatch Agent active
- Docker event monitor active
- Docker events appearing in CloudWatch Logs
- custom metrics appearing in the `EngineeringForFailure` namespace
- failure alarms in `OK`
- SNS subscription confirmed

## Author

**Kevin Harding**

Cloud / DevOps Engineer

---

## License

This project is intended as a hands-on cloud engineering and DevOps portfolio project. Add a license appropriate for your intended use, such as the MIT License.
