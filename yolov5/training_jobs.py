import boto3
import json
import os
import yaml

# YOLOv5 training function
import train

import pickle

s3_client = boto3.client('s3')
s3_resource = boto3.resource('s3')
sagemaker_client = boto3.client('sagemaker')

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
        if not os.path.exists(os.path.dirname(obj.key)):
            os.makedirs(os.path.dirname(obj.key))
        if obj.key[-1] == '/':
            continue
        if os.path.exists(obj.key) and remote_last_modified == int(os.path.getmtime(obj.key)):
            print("File " + obj.key + " is up to date")
        else:
            print("Downloading " + obj.key + " from the S3 bucket")
            bucket.download_file(obj.key, obj.key)
            os.utime(obj.key, (remote_last_modified, remote_last_modified))

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
            bucket_name = int(tag['Value'])
        if tag['Key'] == 'num_finetuning_epochs':
            bucket_name = int(tag['Value'])
        if tag['Key'] == 'batch_size':
            bucket_name = int(tag['Value'])

    s3_client.download_file('pending_models_job.txt', bucket_name, 'pending_models_job.txt')
    s3_client.download_file('models_job.txt', bucket_name, 'models_job.txt')
    pending_models_to_train = []
    models_to_train = []
    with open('pending_models_job.txt', 'r') as file:
        pending_models_to_train = [line.strip() for line in list(filter(None, file.read().split('\n')))]
    with open('models_job.txt', 'r') as file:
        models_to_train = [line.strip() for line in list(filter(None, file.read().split('\n')))]

    for pending_model in pending_models_to_train:
        download_model_data(bucket_name, pending_model, is_pending=True)
        # Train starting from YOLOv5s model with COCO weights
        train.run(batch_size=batch_size, epochs=num_training_epochs, data='./pending_models/{model}/{model}.yaml'.format(model=pending_model), weights='yolov5s.pt', project=pending_model, name='', exist_ok=True, nosave=True)
        with open ('val_APs.pickle', 'rb') as fp:
            val_APs = pickle.load(fp)
        
        model_data = read_model_data_yaml(pending_model, is_pending=True)
        model_data['training_set_size'] = len(os.listdir('pending_models/' + pending_model + '/labels/train/'))
        model_data['validation_set_size'] = len(os.listdir('pending_models/' + pending_model + '/labels/valid/'))
        model_data['validation_APs'] = val_APs.tolist()
        
        # Write new yaml
        with open('models/{model}/{model}.yaml'.format(model=pending_model), 'w') as file:
            yaml.dump(model_data, file)
        
        # Remove model from pending models in S3
        move_pending_model(bucket_name, pending_model)
        # Upload new yaml
        s3_client.upload_file('pending_models/{pending_model}/{pending_model}.yaml'.format(pending_model=pending_model), bucket_name, 'models/{pending_model}/{pending_model}.yaml'.format(pending_model=pending_model))
        # Upload actual model with weights
        s3_client.upload_file('pending_models/' + pending_model + '/weights/last.pt', bucket_name, 'models/{pending_model}/{pending_model}.pt'.format(pending_model=pending_model))

    for model in models_to_train:
        download_model_data(bucket_name, pending_model, is_pending=False)
        # Finetune from pre-existing model pt
        train.run(batch_size=batch_size, epochs=num_finetuning_epochs, data='./models/{model}/{model}.yaml'.format(model=model), weights='./models/{model}/{model}.pt'.format(model=model), project=model, name='', exist_ok=True, nosave=True, noval=True)
        
        with open ('val_APs.pickle', 'rb') as fp:
            val_APs = pickle.load(fp)
        
        model_data = read_model_data_yaml(model, is_pending=False)
        model_data['training_set_size'] = len(os.listdir('models/' + model + '/labels/train/'))
        model_data['validation_set_size'] = len(os.listdir('models/' + model + '/labels/valid/'))
        model_data['validation_APs'] = val_APs.tolist()

        # Write new yaml
        with open('models/{model}/{model}.yaml'.format(model=model), 'w') as file:
            yaml.dump(model_data, file)

        # Upload new yaml
        s3_client.upload_file('models/{model}/{model}.yaml'.format(model=model), bucket_name, 'models/{model}/{model}.yaml'.format(model=model))
        # Upload actual model with weights
        s3_client.upload_file('models/' + model + '/weights/last.pt', bucket_name, 'models/{model}/{model}.pt'.format(model=model))
    
    # DONE!

    # Make the notebook instance stop itself
    sagemaker_client.stop_notebook_instance(NotebookInstanceName=notebook_name)