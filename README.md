## About ##

This project is a set of scripts to query Google Analytics data for DLTS sites and also parse RStar storage reports.  These scripts then create new CSV reports that are emailed to specified recipients.

## Requirements ##

- chronic gem
- fiscali gem
- google-api-client gem
- mail gem
- mechanize gem
- thor gem
- Ruby >= 2.0

## Install ##

You will first need to install the gems

    bundle

or install them individually

    gem install chronic
    gem install fiscali
    gem install google-api-client -v 0.9.1
    gem install mail
    gem install mechanize
    gem install thor

Once the gems are installed you must enable the Google Analytics API
in the Developers Console using the wizard

    https://console.developers.google.com/flows/enableapi?apiid=analytics

Complete the steps below:

- Use this wizard to create or select a project in the Google Developers Console and automatically turn on the API. Click Continue, then Go to credentials.
- On the Add credentials to your project page, click the Cancel button.
- At the top of the page, select the OAuth consent screen tab. Select an Email address, enter a Product name if not already set, and click the Save button.
- Select the Credentials tab, click the Create credentials button and select OAuth client ID.
- Select the application type Other, enter the name "Google Calendar API Quickstart", and click the Create  button.
- Click OK to dismiss the resulting dialog.
- Click the file download (Download JSON) button to the right of the client ID.
- Move this file to your working directory and rename it client_secret.json.

## Usage ##

To see a list of all available options available run the script with the '-h' help switch:

    ./analytics-reporter.rb -h

To generate an analytics report for the 1st Quarter of the 2016 fiscal year

    ./analytics-reporter.rb -f Q1/2016

To generate a storage report for the 4th Quarter of the 2015 fiscal year

    ./storage-reporter.rb -f Q4/2015

