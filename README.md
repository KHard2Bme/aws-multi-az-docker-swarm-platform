# Engineering for Failure: Building a Resilient, Self-Healing Container Platform on AWS

![AWS](https://img.shields.io/badge/AWS-Cloud-orange)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)
![Docker](https://img.shields.io/badge/Container-Docker-blue)
![CloudWatch](https://img.shields.io/badge/Monitoring-CloudWatch-ff9900)
![Amazon Linux](https://img.shields.io/badge/OS-Amazon%20Linux%202023-green)
![Status](https://img.shields.io/badge/Project-Version%202-success)

## Testing Failure, Recovery, and Resilience with Terraform, Docker Swarm, CloudWatch, Auto Scaling, and Amazon SNS

A hands-on AWS and Docker Swarm resilience project designed to demonstrate how a distributed application platform responds to **container failures, worker failures, manager failures, planned maintenance events, load balancer failures, and Auto Scaling recovery scenarios**.

The project uses Terraform to provision a Multi-AZ AWS environment with a three-node Docker Swarm manager control plane, worker capacity distributed across three Availability Zones, an Application Load Balancer, CloudWatch monitoring, automated alarms, SNS notifications, and repeatable failure-testing procedures.

---

## 📌 Project Overview

The goal of this project is not simply to deploy containers.

The environment was intentionally designed to answer a more important question:

> **What happens when part of the platform fails?**

The project demonstrates:

- Docker Swarm service self-healing
- Container replacement
- Worker node workload redistribution
- Manager quorum resilience
- Multi-AZ worker placement
- Application Load Balancer health monitoring
- CloudWatch Agent custom infrastructure metrics
- Docker event logging
- CloudWatch metric filters
- CloudWatch alarms and SNS notifications
- Planned maintenance procedures
- Worker recovery and rejoining
- ALB unhealthy-target testing
- Auto Scaling recovery testing
- Evidence collection through CloudWatch, Docker commands, and browser validation

---

# 🎯 Project Goals

The primary goals of Version 2 are to:

1. Build a resilient Docker Swarm platform across multiple AWS Availability Zones.
2. Separate the Swarm control plane from application workloads.
3. Run application services across workers in different Availability Zones.
4. Automatically recover from container and worker failures.
5. Maintain manager quorum during manager failures.
6. Monitor infrastructure and Docker events with Amazon CloudWatch.
7. Generate alerts for important failure conditions.
8. Demonstrate resilience during planned operational maintenance.
9. Validate Application Load Balancer health behavior.
10. Validate worker replacement and recovery through Auto Scaling.
11. Document repeatable failure and recovery procedures.

---

# 🏗️ Architecture

```text
                              Internet
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │ Application Load Balancer│
                    │        Port 80           │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     Target Group         │
                    └───────┬────────┬─────────┘
                            │        │
             ┌──────────────┘        └──────────────┐

      us-east-1a              us-east-1b              us-east-1c
 ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
 │ Apache Service A │    │ Apache Service B │    │ Apache Service C │
 │ Worker A         │    │ Worker B         │    │ Worker C         │
 │ role=worker      │    │ role=worker      │    │ role=worker      │
 │ az=us-east-1a    │    │ az=us-east-1b    │    │ az=us-east-1c    │
 └──────────────────┘    └──────────────────┘    └──────────────────┘

                  Docker Swarm Manager Control Plane

 ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
 │ Manager 1        │    │ Manager 2        │    │ Manager 3        │
 │ Leader           │    │ Reachable        │    │ Reachable        │
 │ Availability:    │    │ Availability:    │    │ Availability:    │
 │ Drain            │    │ Drain            │    │ Drain            │
 └──────────────────┘    └──────────────────┘    └──────────────────┘

                     Monitoring and Alerting

 Workers / Managers
          │
          ├── CloudWatch Agent
          │     ├── CPU
          │     ├── Memory
          │     └── Network
          │
          ├── Docker Event Monitor
          │     └── /var/log/docker-events.log
          │
          ▼
 ┌───────────────────────────────┐
 │ Amazon CloudWatch             │
 │                               │
 │ • Custom Metrics              │
 │ • Docker Logs                 │
 │ • Metric Filters              │
 │ • Dashboard                   │
 │ • Alarms                      │
 └───────────────┬───────────────┘
                 │
                 ▼
           Amazon SNS
                 │
                 ▼
            Email Alert
```

---

# 🧰 Technology Stack

| Technology | Purpose |
|---|---|
| AWS EC2 | Docker Swarm managers and workers |
| AWS VPC | Network isolation |
| Public Subnets | Application Load Balancer access |
| Private Subnets | Docker Swarm worker infrastructure |
| NAT Gateway | Outbound internet access for private workers |
| Application Load Balancer | Application traffic distribution and health checks |
| Auto Scaling | Worker capacity recovery |
| Docker | Container runtime |
| Docker Swarm | Container orchestration and self-healing |
| Terraform | Infrastructure as Code |
| AWS Systems Manager Parameter Store | Swarm bootstrap configuration and CloudWatch Agent configuration |
| CloudWatch Agent | CPU, memory, and network metrics |
| CloudWatch Logs | Docker event logging |
| CloudWatch Metric Filters | Failure-event detection |
| CloudWatch Dashboard | Infrastructure and failure visibility |
| CloudWatch Alarms | Automated failure detection |
| Amazon SNS | Email notifications |
| IAM | Least-privilege instance permissions |
| Amazon Linux 2023 | EC2 operating system |
| Bash | Bootstrap and monitoring automation |

---

# 📁 Repository Structure

```text
aws-multi-az-docker-swarm-platform/
│
├── scripts/
│   ├── manager_bootstrap.sh
│   ├── worker_bootstrap.sh
│   └── docker_event_monitor.sh
│
├── cloudwatch.tf
├── iam.tf
├── main.tf
├── outputs.tf
├── variables.tf
├── providers.tf
├── docker-stack.yml
└── README.md
```

---

# 🐳 Docker Swarm Design

## Manager Nodes

Three Docker Swarm managers provide the control plane.

The managers are configured with:

```text
Availability: Drain
```

This prevents application workloads from being scheduled on the managers and keeps them dedicated to cluster management.

Typical state:

```text
Manager1 → Leader
Manager2 → Reachable
Manager3 → Reachable
```

A three-manager design allows the cluster to tolerate the loss of one manager while maintaining quorum.

---

## Worker Nodes

Workers are distributed across three Availability Zones.

| Worker | Availability Zone | Labels |
|---|---|---|
| Worker A | us-east-1a | role=worker, workload=application, az=us-east-1a |
| Worker B | us-east-1b | role=worker, workload=application, az=us-east-1b |
| Worker C | us-east-1c | role=worker, workload=application, az=us-east-1c |

The application is deployed as three separate services to demonstrate AZ-aware placement:

```text
apache-a → Worker A / us-east-1a
apache-b → Worker B / us-east-1b
apache-c → Worker C / us-east-1c
```

This makes failure testing easier to observe and provides predictable workload placement.

> **ASG replacement note:** A replacement worker receives a new EC2 instance identity and Docker Swarm node identity. In the current Version 2 implementation, the replacement worker automatically bootstraps and rejoins the Swarm, but the required `workload=application` and `az=<Availability-Zone>` labels are applied manually from `manager-1` before the placement-constrained application service can be scheduled.

---

# 📊 CloudWatch Monitoring

## CloudWatch Agent

The CloudWatch Agent collects custom infrastructure metrics in the:

```text
EngineeringForFailure
```

namespace.

Metrics include:

```text
cpu_usage_idle
cpu_usage_user
cpu_usage_system
mem_used_percent
bytes_sent
bytes_recv
```

Metrics are collected from the EC2 instances using the CloudWatch Agent.

---

## Docker Event Monitoring

A Docker event monitoring service captures selected Docker lifecycle events.

The monitored events include:

```text
die
stop
```

Events are written to:

```text
/var/log/docker-events.log
```

The CloudWatch Agent forwards the events to:

```text
/engineering-for-failure/docker
```

This provides a centralized record of container and Docker-related events.

### Monitoring Services

The project uses separate monitoring components for different responsibilities:

- **CloudWatch Agent** — collects CPU, memory, and network metrics and forwards Docker event logs.
- **Docker Event Monitor** — captures selected Docker lifecycle events and writes them to `/var/log/docker-events.log`.
- **Docker Service Failure Monitor** — runs as a systemd service on the nodes to detect Docker service/node failure conditions and write corresponding events to the Docker event log.
- **CloudWatch Metric Filters** — convert relevant event-log entries into failure metrics.
- **CloudWatch Dashboard** — provides visual evidence of infrastructure and failure conditions.
- **CloudWatch Alarms** — evaluate failure metrics and ALB health metrics.
- **Amazon SNS** — sends email notifications when configured alarms enter `ALARM`.

The Docker event monitor and Docker service failure monitor are intended to run as systemd services on the project nodes.

---

# 🚨 CloudWatch Metric Filters

Metric filters convert relevant log events into CloudWatch metrics.

The project includes:

```text
ContainerFailureFilter
WorkerNodeFailureFilter
ManagerNodeFailureFilter
```

These metrics support dashboard visibility and CloudWatch alarms.

---

# 🔔 CloudWatch Alarms and SNS

The project includes four primary CloudWatch alarms:

1. Container Failure
2. Worker Node Failure
3. Manager Node Failure
4. ALB Unhealthy Hosts

When an alarm enters the `ALARM` state, Amazon SNS sends an email notification to the configured subscriber.

The SNS subscription must be confirmed before notifications are delivered.

---

# 📈 Focused CloudWatch Dashboard

The Version 2 dashboard focuses on the signals most useful during failure testing.

## Infrastructure

- Manager CPU Utilization
- Manager Status Checks

## Worker Monitoring

- Worker CPU Usage

## Failure Monitoring

- Container Failures
- Worker Node Failures
- Manager Node Failures

## Application Load Balancer

- ALB Healthy Hosts
- ALB Unhealthy Hosts

These eight widgets provide a focused view of the platform's health during resilience testing.

### Failure-Test Dashboard Evidence

| Test condition | Expected behavior | Observed CloudWatch Dashboard evidence | Explanation |
|---|---|---|---|
| Container Failure | Container failure should be detected and Swarm should replace the failed task. | **Container Failures = 2** during the detected failure. | Two relevant container lifecycle failure events were captured by the monitoring pipeline. |
| Worker Node Failure | Worker failure should be detected; the affected ALB target may become unhealthy while workload recovery occurs. | **Worker Node Failures = 1** and **ALB Unhealthy Hosts = 1**. | Matches the expected worker failure and ALB impact. |
| Manager Node Failure | Manager failure should be detected while the remaining managers maintain quorum. | **Manager Node Failures = 1** during the detected manager failure. | Matches the expected manager failure detection. |
| Drain a Worker | Planned drain should not represent an infrastructure failure, but moving a workload can generate container lifecycle events. | **Container Failures = 2** during the detected maintenance event. | These were container lifecycle events associated with workload movement; they do not mean two worker nodes failed. |
| Reboot a Worker | A planned reboot may cause a brief node interruption; detection depends on the monitoring interval and interruption duration. | **Worker Node Failures = 1**. | The reboot interruption was long enough to satisfy the project's worker-node failure detection logic. |
| Restart Docker on a Worker | A brief Docker runtime restart should recover without a failure alarm if it completes before the monitoring threshold. | **No failure widgets triggered.** | The Docker restart recovered before a qualifying sustained failure was detected. A running container alone does not create a ContainerFailure metric. |
| Restart Docker on a Drained Manager | A planned Docker restart should preserve quorum while managers remain excluded from application workloads. | **Manager Node Failure = 1**. | The manager Docker-service interruption was detected even though quorum remained intact. |
| ALB / Target Failure | The affected target should fail its ALB health check and `UnHealthyHostCount` should increase. | **ALB Unhealthy Hosts = 3** during the recovery window. | This counts unhealthy registered targets, not EC2 instances intentionally shut down. Original worker-a was **Draining**, while worker-b, worker-c, and the replacement worker-a were **Unhealthy** at that measurement point. |
| ASG Worker Replacement | ASG should launch replacement capacity; the worker should join Swarm, receive required labels, host the workload, and restore ALB health. | **ALB Unhealthy Hosts = 1** while the affected target was unavailable. | Matches the expected temporary impact during replacement. The replacement initially required the application placement labels before the constrained workload could be scheduled. |

> **Evidence note:** The **Expected behavior** column describes what the test is intended to demonstrate; the **Observed CloudWatch Dashboard evidence** column records what actually occurred during Version 2 testing. Differences are documented rather than changed to match a predetermined value. Dashboard values can be transient, so correlate them with the Docker event log, node/service state, ALB target health, CloudWatch alarm state, SNS notification, and recovery state.

---

# ✅ Baseline Validation

Before failure testing, confirm that the environment is healthy.

## Docker Swarm

```bash
sudo docker node ls
```

Expected:

- Three managers are `Ready`.
- Three workers are `Ready`.
- Managers are in `Drain`.
- Workers are `Active`.

## Services

```bash
sudo docker service ls
```

Expected:

```text
apache-a   1/1
apache-b   1/1
apache-c   1/1
```

## Service Placement

```bash
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ps engineering-for-failure_apache-b
sudo docker service ps engineering-for-failure_apache-c
```

## ALB Health

Confirm all targets are healthy in the AWS console.

## Application Test

```bash
curl -I http://<ALB-DNS-NAME>
```

Expected:

```text
HTTP/1.1 200 OK
```

## CloudWatch

Confirm:

- CloudWatch Agent is active.
- Docker event monitor is active.
- Custom metrics are appearing.
- Docker events are appearing in CloudWatch Logs.
- All alarms are in `OK` state before testing.

---

# 🧪 Version 2 Complete Test Plan

The following tests are divided into:

1. Primary failure scenarios
2. Operational maintenance scenarios
3. Application Load Balancer testing
4. Auto Scaling Group testing

For each scenario, capture evidence before, during, and after recovery.

## Test Scenario Coverage

The nine scenarios intentionally exercise different failure and operational layers:

| Scenario | Primary concept demonstrated |
|---|---|
| Container Failure | Container-level self-healing and service replacement |
| Worker Node Failure | Worker/node failure detection, workload recovery, monitoring, and ALB impact |
| Manager Node Failure | Docker Swarm control-plane resilience and quorum |
| Drain a Worker Node | Planned maintenance and graceful workload management |
| Reboot a Worker Node | Host/operating-system restart recovery |
| Restart Docker on a Worker | Docker Engine/runtime restart recovery |
| Restart Docker on a Drained Manager | Control-plane maintenance while managers remain excluded from application workloads |
| ALB / Target Failure | Application Load Balancer health checks and unhealthy-target monitoring |
| ASG Worker Replacement | Infrastructure self-healing, bootstrap, Swarm rejoin, workload restoration, and ALB recovery |

The tests overlap intentionally where one failure can produce evidence at multiple layers. The objective is to validate the complete resilience chain rather than repeat identical tests.

---

# 🚨 Primary Failure Scenario 1 — Container Failure

## Purpose

Validate Docker Swarm's ability to detect a failed container and automatically schedule a replacement.

## Failure Command

Identify the container:

```bash
sudo docker ps
```

Stop the application container:

```bash
sudo docker stop <CONTAINER_ID>
```

## Expected Result

- Docker container stops.
- Docker event is generated.
- CloudWatch receives the event.
- Container failure metric is generated.
- CloudWatch alarm may enter `ALARM`.
- Docker Swarm schedules a replacement.
- Application remains available.

## Recovery

No manual recovery should be required.

Validate:

```bash
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ls
sudo docker ps
```

## Evidence

- `docker service ps`
- `docker ps`
- CloudWatch Dashboard
- CloudWatch Alarm
- Browser or `curl` validation
- **CloudWatch Dashboard: Observed result was Container Failures = 2 during the detected failure.**

---

# 🚨 Primary Failure Scenario 2 — Worker Node Failure

**Expected temporary application impact may occur while workloads are being recovered.**

## Purpose

Validate workload redistribution when a worker becomes unavailable.

## Failure Command

On the selected worker:

```bash
sudo systemctl stop docker
```

## Expected Result

- Worker becomes unavailable.
- Docker Swarm detects the failure.
- Worker failure monitoring is triggered.
- Tasks are redistributed where placement constraints allow.
- Application availability is validated through the ALB.

## Recovery Command

On the worker:

```bash
sudo systemctl start docker
```

Validate:

```bash
sudo systemctl status docker --no-pager
```

From a manager:

```bash
sudo docker node ls
sudo docker service ps engineering-for-failure_apache-a
sudo docker service ps engineering-for-failure_apache-b
sudo docker service ps engineering-for-failure_apache-c
```

## Evidence

- `docker node ls`
- `docker service ps`
- CloudWatch Dashboard
- CloudWatch alarms
- Browser or `curl` validation
- **CloudWatch Dashboard: Worker Node Failures should show 1 and ALB Unhealthy Hosts should show 1 while the affected worker/target is unhealthy.**

---

# 🚨 Primary Failure Scenario 3 — Manager Node Failure

## Purpose

Validate Docker Swarm manager quorum and continued cluster availability.

## Failure Command

On a non-leader manager:

```bash
sudo systemctl stop docker
```

## Expected Result

- Selected manager becomes unavailable.
- Remaining two managers maintain quorum.
- Cluster management continues.
- Application services remain available.

## Recovery Command

```bash
sudo systemctl start docker
```

Validate:

```bash
sudo systemctl status docker --no-pager
```

From the active manager:

```bash
sudo docker node ls
sudo docker service ls
```

## Evidence

- `docker node ls`
- `docker service ls`
- CloudWatch Dashboard
- CloudWatch alarms
- Browser or `curl` validation
- **CloudWatch Dashboard: Manager Node Failures should show 1 during the detected manager failure.**

---

# 🔧 Operational Test 1 — Drain a Worker Node

## Purpose

Simulate planned maintenance without abruptly failing the server.

## Maintenance Command

From a manager:

```bash
sudo docker node update --availability drain <WORKER-NODE>
```

## Expected Result

- Worker enters `Drain`.
- New workloads are not scheduled to the worker.
- Existing workloads are redistributed when possible.
- Application remains available.

## Recovery Command

After maintenance:

```bash
sudo docker node update --availability active <WORKER-NODE>
```

Validate:

```bash
sudo docker node ls
sudo docker service ps <SERVICE-NAME>
```

## Evidence

- `docker node ls`
- `docker service ps`
- CloudWatch Dashboard
- Browser or `curl` validation
- **CloudWatch Dashboard: Observed result was Container Failures = 2 during the drain; these represent container lifecycle events associated with workload movement, not two node failures.**

---

# 🔧 Operational Test 2 — Reboot a Worker Node

**The EC2 reboot temporarily stops the Docker event monitor and CloudWatch Agent until the instance returns.**

## Purpose

Validate recovery after planned operating system or infrastructure maintenance.

## Failure / Maintenance Command

On the worker:

```bash
sudo reboot
```

## Expected Result

- Worker temporarily leaves or becomes unavailable.
- Remaining infrastructure continues serving the application.
- Worker boots again.
- Docker, CloudWatch Agent, and supporting services recover.
- Worker rejoins the Swarm.

## Recovery Validation

After reconnecting:

```bash
sudo systemctl status docker --no-pager
sudo systemctl status amazon-cloudwatch-agent --no-pager
sudo systemctl status docker-event-monitor --no-pager
```

From a manager:

```bash
sudo docker node ls
sudo docker service ls
```

## Evidence

- `docker node ls`
- Service status
- CloudWatch Dashboard
- Browser or `curl` validation
- **CloudWatch Dashboard: Observed result was Worker Node Failures = 1; the reboot interruption was long enough to be detected by the worker-node monitoring logic.**

---

# 🔧 Operational Test 3 — Restart Docker Service on a Worker

## Purpose

Simulate Docker Engine maintenance, configuration changes, or troubleshooting.

## Failure Command

```bash
sudo systemctl stop docker
```

Or:

```bash
sudo systemctl restart docker
```

## Expected Result

- Worker temporarily becomes unavailable.
- Docker workloads on the worker are interrupted.
- Swarm reacts to the unavailable node.
- Node reconnects when Docker starts again.

## Recovery Command

If Docker was stopped:

```bash
sudo systemctl start docker
```

Validate:

```bash
sudo systemctl status docker --no-pager
```

From a manager:

```bash
sudo docker node ls
sudo docker service ls
```

---

# 🔧 Operational Test 4 — Restart Docker on a Drained Manager

## Purpose

Simulate Docker Engine maintenance on a manager while ensuring application workloads are not running on the control plane.

The managers are intentionally configured as:

```text
Availability: Drain
```

## Maintenance Command

On a non-leader manager:

```bash
sudo systemctl restart docker
```

## Expected Result

- Selected manager temporarily disconnects.
- Remaining managers maintain quorum.
- Application workloads remain unaffected because managers are drained.
- Manager returns to `Ready` after Docker restarts.

## Recovery Validation

On the manager:

```bash
sudo systemctl status docker --no-pager
```

From the leader:

```bash
sudo docker node ls
sudo docker service ls
```

Confirm the manager remains:

```text
Ready
Drain
```

---

# ⚖️ Application Load Balancer Test — Unhealthy Target

## Purpose

Validate ALB health checks and CloudWatch monitoring when an application target becomes unhealthy.

## Failure Action

On the worker hosting a selected application service, stop Docker or otherwise stop the service's container.

For example:

```bash
sudo docker stop <CONTAINER_ID>
```

## Expected Result

- Target may become unhealthy.
- `UnHealthyHostCount` increases.
- CloudWatch alarm can enter `ALARM`.
- ALB continues routing traffic to healthy targets.
- Docker Swarm may replace the failed task.

## Recovery

Allow Docker Swarm to recover the task automatically, or restore the service if it was intentionally stopped.

Validate:

```bash
sudo docker service ps <SERVICE-NAME>
```

Confirm target health returns to healthy.

## Evidence

- Target group health
- CloudWatch Dashboard
- ALB alarm
- Browser or `curl` validation
- **CloudWatch Dashboard: Observed result was ALB Unhealthy Hosts = 3 during the recovery window; this represented three unhealthy registered targets, not three intentionally failed EC2 instances.**

---

# 📈 Auto Scaling Group Test — Worker Replacement

## Purpose

Validate that the infrastructure can restore worker capacity when a worker instance is lost or terminated.

## Failure Action

Perform this test carefully against a worker managed by the appropriate Auto Scaling configuration.

The worker can be terminated from the AWS console or using the AWS CLI according to the project's Auto Scaling configuration.

## Expected Result

- Worker EC2 instance is removed.
- Auto Scaling launches replacement capacity.
- Replacement worker bootstraps.
- Replacement worker installs required services.
- Replacement worker retrieves configuration from Parameter Store.
- CloudWatch Agent starts.
- Docker event monitoring starts.
- Worker joins the Docker Swarm.
- Required application placement labels are applied from `manager-1`:
  - `workload=application`
  - `az=<replacement worker Availability Zone>`
- Swarm schedules the application workload after the labels satisfy the service placement constraints.
- Application workload capacity returns.

## Recovery Validation

From a manager:

```bash
sudo docker node ls
```

Confirm the replacement node becomes:

```text
Ready
Active
```

Check labels:

```bash
sudo docker node inspect <NEW-WORKER> \
  --format '{{json .Spec.Labels}}'
```

If the replacement worker does not yet have the required labels, apply them from `manager-1`:

```bash
sudo docker node update \
  --label-add workload=application \
  --label-add az=<REPLACEMENT-WORKER-AZ> \
  <NEW-WORKER>
```

Then verify:

```bash
sudo docker node inspect <NEW-WORKER> \
  --format '{{json .Spec.Labels}}'
```

Validate:

```bash
sudo docker service ls
sudo docker service ps <SERVICE-NAME>
```

## Evidence

- EC2 instance replacement
- Auto Scaling activity
- `docker node ls`
- Worker labels
- CloudWatch Agent status
- Docker event monitor status
- CloudWatch Dashboard
- Browser or `curl` validation
- **CloudWatch Dashboard: Observed result was ALB Unhealthy Hosts = 1 while the affected target was unavailable; the replacement later became healthy after the required Swarm labels were applied.**

---

# 🔁 General Recovery Validation

After every test, return the environment to a healthy baseline.

Run:

```bash
sudo docker node ls
```

```bash
sudo docker service ls
```

```bash
curl -I http://<ALB-DNS-NAME>
```

Confirm:

- Managers are `Ready`.
- Workers are `Ready`.
- Managers remain `Drain`.
- Workers are `Active`.
- All expected services show desired replicas.
- ALB targets are healthy.
- Application returns HTTP 200.
- CloudWatch alarms return to `OK`.

---

# 📸 Evidence Collection

Recommended screenshots and evidence include:

## Architecture

- AWS VPC and subnet layout
- EC2 instances
- Application Load Balancer
- Target group health
- CloudWatch Dashboard

## Baseline

- `docker node ls`
- `docker service ls`
- Service placement and required worker labels
- Healthy ALB targets
- HTTP 200 response

## Failure Testing

For each failure:

1. Baseline state
2. Failure command
3. Failure detection
4. CloudWatch Dashboard
5. CloudWatch alarm
6. Docker Swarm response
7. Recovery state
8. Application validation

## Operational Testing

Capture:

- Node state before maintenance
- Maintenance command
- Node or service transition
- Application availability
- Recovery validation

---

# 🚀 Deployment

## Clone the Repository

```bash
git clone <YOUR-REPOSITORY-URL>
cd aws-multi-az-docker-swarm-platform
```

## Initialize Terraform

```bash
terraform init
```

## Review the Plan

```bash
terraform plan
```

## Deploy

```bash
terraform apply
```

Enter:

```text
yes
```

---

# 🧹 Destroying and Rebuilding the Environment

For additional practice or a completely fresh environment, Terraform can be used to destroy and recreate the infrastructure.

Destroy:

```bash
terraform destroy
```

Rebuild:

```bash
terraform apply
```

> **Important:** A rebuild can create new EC2 instances, new private IP addresses, new Docker Swarm node identities, and new resources depending on the Terraform configuration. Previous screenshots and runtime state should not be expected to remain valid after destruction.

After rebuilding, repeat:

1. Baseline validation
2. CloudWatch validation
3. ALB validation
4. SNS alarm validation
5. Failure testing
6. Operational testing

After a fresh rebuild, also verify the bootstrap-installed monitoring services and application placement labels before beginning failure testing. For an ASG worker replacement, the replacement receives a new Swarm node identity; in the current implementation, apply the required application placement labels from `manager-1` before expecting an AZ-constrained application service to schedule on the replacement.

---

# 🔐 Security and Operational Design

The project uses IAM roles and instance profiles to provide AWS permissions without embedding AWS credentials in bootstrap scripts.

AWS Systems Manager Parameter Store is used to retrieve runtime configuration required for cluster initialization and monitoring.

The manager and worker roles are separated to support the distinction between:

- Control-plane responsibilities
- Worker runtime responsibilities
- CloudWatch telemetry
- SSM Parameter Store access

---

# 💡 Key Lessons Demonstrated

This project demonstrates several real-world cloud and DevOps concepts:

### Infrastructure as Code

Terraform provides repeatable infrastructure deployment.

### High Availability

Worker nodes are distributed across multiple Availability Zones.

### Control Plane Resilience

Three managers provide quorum protection against a single manager failure.

### Container Orchestration

Docker Swarm automatically manages service replicas and container recovery.

### Observability

CloudWatch provides infrastructure metrics, logs, dashboards, metric filters, and alarms.

### Event-Driven Monitoring

Docker lifecycle events are captured and converted into CloudWatch metrics.

### Automated Alerting

CloudWatch alarms trigger Amazon SNS notifications.

### Operational Resilience

The environment is tested against both unexpected failures and planned maintenance activities.

### Recovery Engineering

Each scenario includes validation steps to confirm that the platform returns to a healthy baseline.

### Troubleshooting and Failure Analysis

The ASG replacement test demonstrated an important operational lesson: successfully launching and joining a replacement EC2 worker to Docker Swarm does not by itself guarantee that an application service can be scheduled. Because the services use AZ-aware placement constraints, the replacement worker must have the required `workload` and `az` labels before Swarm can place the workload. Applying those labels from `manager-1` allowed the service to recover and the ALB targets to return to `Healthy`.

This demonstrates not only automated infrastructure replacement, but also the importance of validating orchestration placement constraints during recovery.

---

# 👤 Author

**Kevin Harding**

Cloud / DevOps Engineer

This project was built as a hands-on portfolio demonstration of:

- AWS infrastructure
- Terraform
- Docker Swarm
- High availability
- Failure testing
- CloudWatch monitoring
- Infrastructure resilience
- Operational recovery

---

# ⭐ Final Project Outcome

The final Version 2 platform demonstrates more than successful infrastructure deployment.

It demonstrates the ability to:

```text
Build → Monitor → Fail → Detect → Alert → Recover → Validate
```

The objective is to treat failure as an expected part of operating distributed infrastructure and to validate that the platform can respond predictably when failures and maintenance events occur.
