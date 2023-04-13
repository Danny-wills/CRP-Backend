import os
import pytest
import unittest
import boto3
from moto import mock_dynamodb
from unittest import mock
from unittest.mock import MagicMock
import lambda_function

@pytest.fixture
def data_field():
    """
    Mock aws credentials
    """
    os.environ['REGION_NAME'] = 'us-east-1'
    os.environ['ACCESS_KEY_ID'] = MagicMock()
    os.environ['SECRET_ACCESS_KEY'] = MagicMock()


@mock_dynamodb
class TestLambdaFunction(unittest.TestCase):      
    """
    Test get_item for status code
    """
    def test_get_item(self):
        event = {}
        context = {}
        response = lambda_function.lambda_handler(event, {})

        self.assertEqual(response['statusCode'], 200)

if __name__ == '__main__':
    unittest.main()
