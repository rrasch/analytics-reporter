#!/usr/bin/env python3

"""A simple example of how to access the Google Analytics API."""

import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.basemap import Basemap

from pprint import pprint

import argparse

from datetime import datetime
import os.path

import httplib2
from apiclient.discovery import build
from oauth2client import client
from oauth2client import file
from oauth2client import tools

SCOPE = ['https://www.googleapis.com/auth/analytics.readonly']

CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'foo'
CREDENTIAL_FILE = 'credentials.json'

def get_service(api_name, api_version, scope, client_secrets_path):
  """Get a service that communicates to a Google API.

  Args:
    api_name: string The name of the api to connect to.
    api_version: string The api version to connect to.
    scope: A list of strings representing the auth scopes to authorize for the
      connection.
    client_secrets_path: string A path to a valid client secrets file.

  Returns:
    A service that is connected to the specified API.
  """
  # Parse command-line arguments.
  parser = argparse.ArgumentParser(
      formatter_class=argparse.RawDescriptionHelpFormatter,
      parents=[tools.argparser])
  flags = parser.parse_args([])

  dirname = os.path.join(os.environ['HOME'], '.analytics')
  credential_path = os.path.join(dirname, CREDENTIAL_FILE)
  client_secret_file = os.path.join(dirname, CLIENT_SECRET_FILE)

  # Set up a Flow object to be used if we need to authenticate.
  flow = client.flow_from_clientsecrets(
      client_secret_file, scope=SCOPE,
      message=tools.message_if_missing(client_secret_file))

  # Prepare credentials, and authorize HTTP object with them.
  # If the credentials don't exist or are invalid run through the native client
  # flow. The Storage object will ensure that if successful the good
  # credentials will get written back to a file.
  #storage = file.Storage(api_name + '.dat')
  storage = file.Storage(credential_path)
  credentials = storage.get()
  if credentials is None or credentials.invalid:
    credentials = tools.run_flow(flow, storage, flags)
  http = credentials.authorize(http=httplib2.Http())

  # Build the service object.
  service = build(api_name, api_version, http=http)

  return service


def get_first_profile_id(service):
  # Use the Analytics service object to get the first profile id.

  # Get a list of all Google Analytics accounts for the authorized user.
  accounts = service.management().accounts().list().execute()

  for account in accounts.get('items'):
    # Get the first Google Analytics account.
    name = account.get('name')
    print(name)
    #print(account)

    account_id = account.get('id')

    # Get a list of all the properties for the first account.
    properties = service.management().webproperties().list(
        accountId=account_id).execute()

    i=0
    for property in properties.get('items'):
      # Get the first property id.

      #property = properties.get('items')[0].get('id')
      #print(i)
      #print(property)
      property_id = property.get('id')

      # Get a list of all views (profiles) for the first property.
      profiles = service.management().profiles().list(
          accountId=account_id,
          webPropertyId=property_id).execute()

      for profile in profiles.get('items'):
        # return the first view (profile) id.
        print()
        pprint(profile)
        #return profiles.get('items')[0].get('id')

  return None


def get_results(service, profile_id):
  # Use the Analytics Service Object to query the Core Reporting API
  # for the number of sessions in the past seven days.
  return service.data().ga().get(
      ids='ga:' + profile_id,
      start_date='7daysAgo',
      end_date='today',
      metrics='ga:sessions').execute()


def print_results(results):
  # Print data nicely for the user.
  if results:
    print('View (Profile): %s' % results.get('profileInfo').get('profileName'))
    print('Total Sessions: %s' % results.get('rows')[0][0])

  else:
    print('No results found')


def main():
  # Define the auth scopes to request.
  scope = ['https://www.googleapis.com/auth/analytics.readonly']

  # Authenticate and construct service.
  service = get_service('analytics', 'v3', scope, 'client_secrets.json')
  #service = get_service('analyticsreporting', 'v4', scope, 'client_secrets.json')
  profile = get_first_profile_id(service)
  #print_results(get_results(service, profile))


if __name__ == '__main__':
  main()
