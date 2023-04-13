# Import the requried modules
import json
import boto3

# Create a resource representing a Dynamodb table
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table('visitor_counter')



# This function updates the number of visitors for each time this function is run
def update_item():
    """
    This code updates/increases the number of visits by 1 for each time the website is been opened which runs the lambda function.

    """
    table.update_item(
        Key={
            'visitors': 'visits'
        },
        UpdateExpression='SET visits = visits + :val1',
        ExpressionAttributeValues={
            ':val1': 1
        }
    )


def get_item():
    """
    This function retrieves the updated number of visits from the dynamodb table each time this lambda function is been run.

    """
    response = table.get_item(
        Key={
            'visitors': 'visits'
        }
    )
    return response


def lambda_handler(event, context):
    """
    This function increments the number of visits by calling the update_item() function and gets the number of visits by calling the get_item() function.

    Returns:
        The number of visits after each reaload

    """

    response = get_item()
    update_item()
    

    item = response['Item']
    display = str(item['visits'])
    result = {
        "isBase64Encoded": "",
        "statusCode": 200,
        "headers": {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        },
        "body": json.dumps({"visits": display})
    }

    return result
