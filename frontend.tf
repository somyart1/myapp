

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# Create an SQS Queue
resource "aws_sqs_queue" "task_queue" {
  name = "task-queue"
}

# IAM Role for EC2 instances to access SQS
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:*"],
      Resource = [aws_sqs_queue.task_queue.arn]
    }]
  })
}


data "template_file" "index_html" {
  template = file("index.html")
}

data "template_file" "app_py" {
  template = file("app.py")
}

# Create Frontend EC2 Instance
resource "aws_instance" "frontend" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Use a suitable AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  security_groups        = [aws_security_group.ec2_sg.name]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
			  yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              yum install -y python3 pip
              pip3 install flask boto3
              mkdir -p /var/www/html
              
              # Copy the files
              echo '${data.template_file.index_html.rendered}' > /var/www/html/index.html
              echo '${data.template_file.app_py.rendered}' > /var/www/html/app.py

              echo 'FLASK_APP=/var/www/html/app.py' >> /etc/environment
              source /etc/environment
              nohup python3 /var/www/html/app.py &
              EOF

  tags = {
    Name = "frontend-instance"
  }
}
# IAM Instance Profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}