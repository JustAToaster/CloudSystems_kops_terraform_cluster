import json
import os
import shutil
import time

import yaml

# YOLOv5 training function
import train

import pickle

import boto3

s3_client = boto3.client('s3')
s3_resource = boto3.resource('s3')
sagemaker_client = boto3.client('sagemaker')
logs_client = boto3.client('logs')

log_group_name = ''
log_stream_name = ''

# Log message to CloudWatch
def log_message(message):
    timestamp = int(round(time.time() * 1000))
    response = logs_client.put_log_events(logGroupName=log_group_name,logStreamName=log_stream_name, logEvents=[{'timestamp': timestamp, 'message': message}])
    return response

def get_notebook_name_and_arn():
    log_path = '/opt/ml/metadata/resource-metadata.json'
    with open(log_path, 'r') as logs:
        _logs = json.load(logs)
    return _logs['ResourceName'], _logs['ResourceArn']

def read_model_data_yaml(model_name, is_pending=False):
    model_folder_prefix = ''
    if is_pending:
        model_folder_prefix = 'pending_'
    with open(model_folder_prefix + 'models/' + model_name + '/' + model_name + '.yaml', 'r') as file:
        model_data = yaml.full_load(file)
    return model_data

def download_model_data(bucket_name, model_name, is_pending=False):
    bucket = s3_resource.Bucket(bucket_name)
    model_prefix = ''
    if is_pending:
        model_prefix = 'pending_'
    for obj in bucket.objects.filter(Prefix=model_prefix + 'models/' + model_name):
        remote_last_modified = int(obj.last_modified.strftime('%s'))
        local_file = obj.key.replace(model_prefix + 'models/', '')
        if not os.path.exists(os.path.dirname(local_file)):
            os.makedirs(os.path.dirname(local_file))
        if obj.key[-1] == '/':
            continue
        if os.path.exists(local_file) and remote_last_modified == int(os.path.getmtime(local_file)):
            log_message("File " + local_file + " is up to date")
        else:
            log_message("Downloading " + obj.key + " from the S3 bucket")
            bucket.download_file(obj.key, local_file)
            os.utime(local_file, (remote_last_modified, remote_last_modified))

def move_pending_model(bucket_name, model_name):
    bucket = s3_resource.Bucket(bucket_name)
    for obj in bucket.objects.filter(Prefix='pending_models/' + model_name):
        filename = obj.key.replace('pending_models/' + model_name, '')
        s3_resource.Object(bucket_name, "models/" + model_name + filename).copy_from(CopySource={"Bucket": bucket_name, "Key": obj.key})
        obj.delete()

if __name__ == "__main__":
    notebook_name, notebook_arn = get_notebook_name_and_arn()
    bucket_name = ''
    num_training_epochs = 100
    num_finetuning_epochs = 20
    batch_size = 16
    for tag in sagemaker_client.list_tags(ResourceArn=notebook_arn)['Tags']:
        if tag['Key'] == 'models_bucket':
            bucket_name = tag['Value']
        if tag['Key'] == 'num_training_epochs':
            num_training_epochs = int(tag['Value'])
        if tag['Key'] == 'num_finetuning_epochs':
            num_finetuning_epochs = int(tag['Value'])
        if tag['Key'] == 'batch_size':
            batch_size = int(tag['Value'])
        if tag['Key'] == 'log_group_name':
            log_group_name = tag['Value']
        if tag['Key'] == 'log_stream_name':
            log_stream_name = tag['Value']

    log_message("Starting training job...")

    s3_client.download_file(bucket_name, 'pending_models_job.txt', 'pending_models_job.txt')
    s3_client.download_file(bucket_name, 'models_job.txt', 'models_job.txt')
    pending_models_to_train = []
    models_to_train = []
    with open('pending_models_job.txt', 'r') as file:
        pending_models_to_train = [line.strip() for line in list(filter(None, file.read().split('\n')))]
    with open('models_job.txt', 'r') as file:
        models_to_train = [line.strip() for line in list(filter(None, file.read().split('\n')))]

    for pending_model in pending_models_to_train:
        log_message("Downloading data for pending model " + pending_model)
        # Model data is saved in the yolov5 folder
        download_model_data(bucket_name, pending_model, is_pending=True)
        # Train starting from YOLOv5s model with COCO weights
        log_message("Starting training job for pending model " + pending_model)
        train.run(batch_size=batch_size, epochs=num_training_epochs, data='{model}/{model}.yaml'.format(model=pending_model), weights='yolov5s.pt', project=pending_model, name='', exist_ok=True, nosave=True)
        log_message("Training job for pending model " + pending_model + "done!")
        with open ('val_APs.pickle', 'rb') as fp:
            val_APs = pickle.load(fp)
        
        model_data = read_model_data_yaml(pending_model, is_pending=True)
        model_data['training_set_size'] = len(os.listdir(pending_model + '/labels/train/'))
        model_data['validation_set_size'] = len(os.listdir(pending_model + '/labels/valid/'))
        model_data['validation_APs'] = val_APs.tolist()
        
        # Write new yaml
        with open('{model}/{model}.yaml'.format(model=pending_model), 'w') as file:
            yaml.dump(model_data, file)
        
        # Remove model from pending models in S3
        move_pending_model(bucket_name, pending_model)
        # Upload new yaml
        s3_client.upload_file('{model}/{model}.yaml'.format(model=pending_model), bucket_name, 'models/{model}/{model}.yaml'.format(model=pending_model))
        # Upload actual model with weights
        s3_client.upload_file(pending_model + '/weights/last.pt', bucket_name, 'models/{model}/{model}.pt'.format(model=pending_model))

    for model in models_to_train:
        log_message("Downloading data for model " + model)
        # Model data is saved in the yolov5 folder
        download_model_data(bucket_name, pending_model, is_pending=False)
        # Finetune from pre-existing model pt
        log_message("Starting fine-tuning for model " + model)
        train.run(batch_size=batch_size, epochs=num_finetuning_epochs, data='./{model}/{model}.yaml'.format(model=model), weights='./{model}/{model}.pt'.format(model=model), project=model, name='', exist_ok=True, nosave=True, noval=True)
        log_message("Fine-tuning for model " + model + "done!")

        with open ('val_APs.pickle', 'rb') as fp:
            val_APs = pickle.load(fp)
        
        model_data = read_model_data_yaml(model, is_pending=False)
        model_data['training_set_size'] = len(os.listdir(model + '/labels/train/'))
        model_data['validation_set_size'] = len(os.listdir(model + '/labels/valid/'))
        model_data['validation_APs'] = val_APs.tolist()

        # Write new yaml
        with open('{model}/{model}.yaml'.format(model=model), 'w') as file:
            yaml.dump(model_data, file)

        # Upload new yaml
        s3_client.upload_file('{model}/{model}.yaml'.format(model=model), bucket_name, 'models/{model}/{model}.yaml'.format(model=model))
        # Upload actual model with weights
        s3_client.upload_file(model + '/weights/last.pt', bucket_name, 'models/{model}/{model}.pt'.format(model=model))
    
    # DONE!
    log_message("All training jobs are done!")
    # Wait until the notebook instance becomes InService before trying to stop it
    while sagemaker_client.describe_notebook_instance(NotebookInstanceName=notebook_name)["NotebookInstanceStatus"] != "InService":
        log_message("SageMaker instance is still not in service...")
        time.sleep(30)

    log_message("Stopping SageMaker instance...")
    sagemaker_client.stop_notebook_instance(NotebookInstanceName=notebook_name)