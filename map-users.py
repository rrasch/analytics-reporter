#!/usr/bin/env python3

"""A simple example of how to access the Google Analytics API."""

import fiscalyear as fy
fy.setup_fiscal_calendar(start_month=9)

now = fy.FiscalDateTime.now()
start_date = now.prev_quarter.start.strftime('%Y-%m-%d')
end_date = now.prev_quarter.end.strftime('%Y-%m-%d')
print(start_date)
print(end_date)


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

import pandas as pd

import pycountry

import re

from geonamescache import GeonamesCache
from geonamescache.mappers import country

gc = GeonamesCache()
countries = gc.get_countries()
countries['ZZ'] = {'iso3': 'ZZZ'}

mapper = country(from_key='iso', to_key='iso3')

pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)
pd.set_option('display.max_colwidth', -1)
# pd.set_option('display.float_format', '{:,.0f}'.format)

SCOPE = ['https://www.googleapis.com/auth/analytics.readonly']

CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'foo'
CREDENTIAL_FILE = 'credentials.json'


country_file = os.path.expanduser('~/data/geo/naturalearthdata.com/ne_10m_admin_0_countries_lakes/ne_10m_admin_0_countries_lakes.csv')

#cdf = pd.read_csv(country_file, usecols=['ISO_A2,C,3', 'ISO_A3,C,3'], index_col='ISO_A2,C,3')
cdf = pd.read_csv(country_file, usecols=['ISO_A2,C,3', 'ISO_A3,C,3'])
cdf.columns = [re.sub(r',C,\d+$', '', col) for col in cdf.columns]
cdf.set_index('ISO_A2', inplace=True)

#print(cdf.head())

#print(cdf.at['US', 'ISO_A3'])

#exit(1)



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


def get_profile_ids(service, foo_list=None):
    # Use the Analytics service object to get profile ids.

    # Get a list of all Google Analytics accounts
    # for the authorized user.
    accounts = service.management().accounts().list().execute()

    profile_ids = []

    for account in accounts.get('items'):
        name = account.get('name')
        print(name)

        if foo_list and name not in foo_list:
            continue

        account_id = account.get('id')

        # Get a list of all views (profiles) for property.
        profiles = service.management().profiles().list(
                accountId=account_id,
                webPropertyId='~all').execute()

        for profile in profiles.get('items'):
            if "master view" not in profile.get('name'):
                continue
            print(profile.get('name'))
            profile_ids.append(profile.get('id'))

#         # Get a list of all the properties for account
#         properties = service.management().webproperties().list(
#                 accountId=account_id).execute()
# 
#         for property in properties.get('items'):
#             property_id = property.get('id')
# 
#             # Get a list of all views (profiles) for property.
#             profiles = service.management().profiles().list(
#                     accountId=account_id,
#                     webPropertyId=property_id).execute()
# 
#             for profile in profiles.get('items'):
#                 print(profile.get('name'))
#                 profile_ids.append(profile.get('id'))

    return profile_ids


def get_results(service, profile_id):
    # Use the Analytics Service Object to query the Core Reporting API
    # for the number of sessions in the past seven days.
    return service.data().ga().get(
            ids='ga:' + profile_id,
            start_date=start_date,
            end_date=end_date,
            #metrics='ga:sessions',
            metrics='ga:sessions,ga:users,ga:pageviews',
            #dimensions='ga:countryIsoCode,ga:country'
            dimensions='ga:countryIsoCode'
            ).execute()


# def print_results(results):
#     # Print data nicely for the user.
#     if results:
#         pprint(results)
# #         print('View (Profile): %s' % results.get('profileInfo').get('profileName'))
# #         print('Total Sessions: %s' % results.get('rows')[0][0])
# 
#     else:
#         print('No results found')


# def conv_iso_2_to_3(iso_2):
#     country = pycountry.countries.get(alpha_2=iso_2)
#     if country:
#         return country.alpha_3
#     else:
#         print(f"COUNTY CODE = {iso_2}")
#         return cdf.at[iso_2, 'ISO_A3']

def conv_iso_2_to_3(iso_2):
    return countries[iso_2]['iso3']


def set_int(df):
    cols = list(df.columns)
    df[cols] = df[cols].astype(int)
    #df[cols] = df[cols].applymap(np.int64)


def create_dataframe(results):
    column_names = []
    for header in results.get('columnHeaders'):
        column_names.append(header.get('name'))
    data = results.get('rows')
    #print(data)
    df = pd.DataFrame(data, columns = column_names)
    df = df.set_index('ga:countryIsoCode')
    set_int(df)
    return df


def main():
    scope = ['https://www.googleapis.com/auth/analytics.readonly']

    # Authenticate and construct service.
    service = get_service('analytics', 'v3', scope, 'client_secrets.json')

    #profile_ids = get_profile_ids(service, ['ACO'])
    profile_ids = get_profile_ids(service)
    pprint(profile_ids)

    total = pd.DataFrame()

    for profile_id  in profile_ids:
        results = get_results(service, profile_id)
        df = create_dataframe(results)
        #with pd.option_context('display.max_rows', None,
        #        'display.max_columns', None):
        #    print(df)
        total = total.add(df, fill_value=0)

    #total['foo'] = total.index.map(conv_iso_2_to_3)

    total.index = [conv_iso_2_to_3(i) for i in total.index]
    total.index.name = 'iso3'
    total.columns = [re.sub(r'^ga:', '', col) for col in total.columns]
    set_int(total)

    total.to_csv('sessions.csv')

    #print(total)

if __name__ == '__main__':
    main()
