from flask import Flask, request, redirect, url_for
import boto3

app = Flask(__name__)
sqs = boto3.client('sqs', region_name='us-east-1')
queue_url = 'SQS_QUEUE_URL'  

@app.route('/submit', methods=['POST'])
def submit_task():
    task_description = request.form['task_description']
    # Dynamically set message attributes and body
    response = sqs.send_message(
        QueueUrl=queue_url,
        DelaySeconds=10,
        MessageAttributes={
            'Title': {
                'DataType': 'String',
                'StringValue': 'Task Submission'
            },
            'Description': {
                'DataType': 'String',
                'StringValue': task_description
            }
        },
        MessageBody=(
            f'Task description: {task_description}'
        )
    )
    return f'Task submitted with MessageId: {response["MessageId"]}'

@app.route('/', methods=['GET'])
def index():
    return app.send_static_file('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
