#!/bin/bash
set -e

echo "Updating packages..."
sudo dnf update -y

echo "Installing Amazon CloudWatch Agent..."
sudo dnf install -y amazon-cloudwatch-agent

sudo touch /var/log/docker-events.log
sudo chmod 644 /var/log/docker-events.log

sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_amazon-cloudwatch-agent.json > /dev/null <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "EngineeringForFailure",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    },
    "metrics_collected": {
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle","cpu_usage_user","cpu_usage_system"],
        "totalcpu": true
      },
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": {
        "resources": ["*"],
        "measurement": ["used_percent"]
      },
      "net": {
        "resources": ["*"],
        "measurement": ["bytes_sent","bytes_recv"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/docker-events.log",
            "log_group_name": "/engineering-for-failure/docker",
            "log_stream_name": "{instance_id}/docker-events",
            "retention_in_days": 14
          }
        ]
      }
    },
    "force_flush_interval": 15
  }
}
EOF

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_amazon-cloudwatch-agent.json \
-s

echo "CloudWatch Agent configured successfully."
echo "Use: echo \"$(date) ContainerFailure linux2023 exited\" | sudo tee -a /var/log/docker-events.log"
