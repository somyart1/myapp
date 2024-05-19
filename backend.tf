resource "aws_instance" "backend" {
  ami           = "ami-0c55b159cbfafe1f0"  # Use a suitable AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.ec2_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y aws-cli jq
              while true; do
                MESSAGE=$(aws sqs receive-message --queue-url ${aws_sqs_queue.task_queue.url} --max-number-of-messages 1)
                if [ -z "$MESSAGE" ]; then
                  sleep 5
                else
                  RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.Messages[0].ReceiptHandle')
                  BODY=$(echo $MESSAGE | jq -r '.Messages[0].Body')
                  echo "Processing task: $BODY"
                  aws sqs delete-message --queue-url ${aws_sqs_queue.task_queue.url} --receipt-handle $RECEIPT_HANDLE
                fi
              done
              EOF

  tags = {
    Name = "backend-instance"
  }
}