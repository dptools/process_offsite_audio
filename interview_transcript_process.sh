#!/bin/bash

# top level pipeline script for transcript side processing
# should be called with path to config file as argument
if [[ -z "${1}" ]]; then
	echo "Please provide a path to settings file"
	exit
fi
config_path=$1

# start by getting the absolute path to the directory this script is in, which will be the top level of the repo
# this way script will work even if the repo is downloaded to a new location, rather than relying on hard coded paths to where I put the repo. 
full_path=$(realpath $0)
repo_root=$(dirname $full_path)
# export the path to the repo for scripts called by this script to also use
export repo_root

# running config file will set up necessary environment variables
source "$config_path"

# confirm study folder exists where it should
# most of the other checks should be unnecessary though - processed folders should have been set up by push side script
# (if that hasn't been run yet, transcript pull just won't have anything to check for and will exit naturally, not a big deal)
cd "$data_root"/PROTECTED
if [[ ! -d $study ]]; then
	echo "Invalid data root path or study ID"
	exit
fi

# let user know script is starting
echo ""
echo "Beginning script - interview transcript preprocessing for:"
echo "$study"
echo "with data root:"
echo "$data_root"
echo "Automatically pulling all new transcripts from TranscribeMe username:"
echo "$transcribeme_username"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

bash "$repo_root"/individual_modules/run_transcription_pull.sh "$data_root" "$study" "$transcribeme_username" "$transcribeme_password"
echo ""
echo "Transcript pull complete"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# TODO - will have other processing steps inserted here once more transcript logistics have been worked out

# send email notifying lab members about transcripts successfully pulled/processed, and those we are still waiting on. 
echo "Emailing status update to lab"
mail -s "[Phone Diary Pipeline Updates] New Transcripts Received from TranscribeMe" "$email_list" < "$repo_root"/transcript_lab_email_body.txt
rm "$repo_root"/transcript_lab_email_body.txt # this will be created by wrapping transcript pull script, cleared out here after email sent
# in future will want to improve how we implement the email list, may be different for different studies
# also may want to improve how we do the subject line so it's less repetitive (include date info possibly? and/or give info on total number of new transcripts? even just study name?)
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
