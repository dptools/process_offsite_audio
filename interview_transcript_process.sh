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

# confirm study folder exists where it should, and has the expected GENERAL/PROTECTED and raw and processed folder paths
cd "$data_root"/PROTECTED
if [[ ! -d $study ]]; then
	echo "Invalid data root path ${data_root} or study ID ${study}"
	exit
fi
if [[ ! -d ../GENERAL/$study ]]; then
	echo "Invalid data root path ${data_root} or study ID ${study}"
	exit
fi
if [[ ! -d $study/raw ]]; then
	echo "Study ${study} folder improperly set up"
	exit
fi
if [[ ! -d $study/processed ]]; then
	echo "Study ${study} folder improperly set up"
	exit
fi
# don't care if there is a raw in GENERAL as I will never use that part, so excluding that check
if [[ ! -d ../GENERAL/$study/processed ]]; then
	echo "Study ${study} folder improperly set up"
	exit
fi
if [[ ! -e ../GENERAL/${study}/${study}_metadata.csv ]]; then
	echo "Study ${study} missing metadata"
	exit
fi
# don't repeat further folder setup here though, because audio side of pipeline should really always be run before transcript
# just want basic check to make sure invalid site IDs don't get traversed

# make directory for logs if needed
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
# keep logs in individual directories per study
if [[ ! -d ${repo_root}/logs/${study} ]]; then
	mkdir "$repo_root"/logs/"$study"
fi
# also have a separate subfolder setup for possible emails to be more easily located
if [[ ! -d ${repo_root}/logs/${study}/emails_sent ]]; then
	mkdir "$repo_root"/logs/"$study"/emails_sent
fi
# save with unique timestamp (unix seconds)
log_timestamp=`date +%s`
# test using console and log file simultaneously
exec >  >(tee -ia "$repo_root"/logs/"$study"/transcript_process_logging_"$log_timestamp".txt)
exec 2> >(tee -ia "$repo_root"/logs/"$study"/transcript_process_logging_"$log_timestamp".txt >&2)

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

# run transcript pull script, also puts together bulk of email update
# use source to maintain environment variable on transcript update boolean
source "$repo_root"/individual_modules/run_transcription_pull.sh "$data_root" "$study" "$transcribeme_username" "$transcribeme_password" "$transcription_language"
echo ""
echo "Transcript pull complete"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# put copies of any newly reviewed transcripts (returned via Lochness) from raw to appropriate processed folder location here
# info on newly reviewed transcripts also appended to email
# use source to maintain environment variable on transcript update boolean
source "$repo_root"/individual_modules/run_transcription_review_update.sh "$data_root" "$study" 
# also run the code that checks for transcripts that were set aside for prescreening but not yet returned by the sites as part of this block
bash "$repo_root"/individual_modules/run_transcription_review_alerts.sh "$data_root" "$study" 
echo ""
echo "Transcript review updates complete"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# run script to get redacted copies of the transcripts into GENERAL
bash "$repo_root"/individual_modules/run_transcript_redaction.sh "$data_root" "$study"
echo ""
echo "Any newly reviewed transcripts have been redacted"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# run script to convert new transcripts in GENERAL to CSV
bash "$repo_root"/individual_modules/run_transcript_csv_conversion.sh "$data_root" "$study"
echo ""
echo "CSV conversion completed for newly redacted transcripts"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# run transcript QC
bash "$repo_root"/individual_modules/run_transcript_qc.sh "$data_root" "$study"
echo ""
echo "Transcript QC completed"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# send email notifying lab members about transcripts successfully pulled/processed, and those we are still waiting on. 
# only send if there is something relevant for this study though - check environment variables set by relevant modules
if [[ "$trans_updates" == 1 || "$review_updates" == 1 ]]; then
	echo "Emailing status update to lab"
	mail -s "[${study} Interview Pipeline Updates] New Transcripts Received" "$lab_email_list" < "$repo_root"/transcript_lab_email_body.txt
	# move email to logs folder for reference if it has real content
	mv "$repo_root"/transcript_lab_email_body.txt "$repo_root"/logs/"$study"/emails_sent/transcript_lab_email_body_"$log_timestamp".txt
else
	echo "No new transcript updates for this study, so no email to send"
	rm "$repo_root"/transcript_lab_email_body.txt
fi
echo ""

# similarly will send the email about transcripts remaining to be reviewed
if [[ -e ${repo_root}/site_review_email_body.txt ]]; then
	echo "Emailing review prompt to site"
	mail -s "[Action Required] ${server_version} Interview Pipeline Transcripts to Review" "$site_email_list" < "$repo_root"/site_review_email_body.txt
	mv "$repo_root"/site_review_email_body.txt "$repo_root"/logs/"$study"/emails_sent/site_review_email_body_"$log_timestamp".txt
else
	echo "No transcriptions requiring review currently for this site"
fi
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# finally run the file accounting updates for this study
echo "Compiling/updating file lists with processing date"
bash "$repo_root"/individual_modules/run_final_transcript_accounting.sh "$data_root" "$study" "$transcription_language"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
