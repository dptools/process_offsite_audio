#!/bin/bash

# basic path settings
data_root="/mnt/ProNET/Lochness/PHOENIX"
study="PronetWU"
export data_root
export study

# auto transcription settings
auto_send_on="Y" # if "N", QC will be calculated without uploading anything to TranscribeMe
export auto_send_on
# rest of settings in this section are only relevant when auto transcription is on
# start with transcribeme username, password setup via separate process described in next section
transcribeme_username="zailyn.tamayo@yale.edu"
export transcribeme_username
# next settings are thresholds for acceptable quality level of a given audio file
length_cutoff=0 # minimum number of seconds for an audio file to be uploaded to TranscribeMe
db_cutoff=40 # minimum overall decibel level for an audio file to be uploaded to TranscribeMe 
export length_cutoff
export db_cutoff
# finally settings to control total cost
auto_send_limit_bool="N"
export auto_send_limit_bool
# if auto_send_limit_bool were "Y" instead, would then also need to provide auto_send_limit, example below
# auto_send_limit=60 # maximum sum of minutes across audio files to go through with this upload
# export auto_send_limit

# settings for automatic email, again only relevant if auto transcription is on
# first addresses for the more thorough updates on most recent files
lab_email_list="philip.wolff@yale.edu,jtbaker@partners.org"
# then addresses to send the site review notification to
site_email_list="zarina.bilgrami@emory.edu,carli.ryan@wustl.edu"
# finally should also supply current server label (mainly for dev versus prod)
server_version="Production"
# for U24 now have language marker setting to add to the files that are uploaded to TranscribeMe, to alert them of what language the audio will be in
transcription_language="ENGLISH"
export lab_email_list
export site_email_list
export server_version
export transcription_language

# finally setup the secure passwords
# provide path to a hidden .sh file that should be viewable only be the user calling the pipeline
# if put inside repository folder, make sure the filename is in the gitignore
# by default, .passwords.sh is already in the gitignore
passwords_path="$repo_root"/.passwords.sh
# passwords_path will be called to set the passwords as temporary environment variables within the pipeline
# the script should contain the following lines, with correct passwords subbed in, and uncommented
# (do not do so in this file, but in the script at passwords_path)
# only password needed as of now is the one for TranscribeMe SFTP account
# transcribeme_password="password"
# export transcribeme_password
source "$passwords_path"
