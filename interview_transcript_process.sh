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

# make directory for logs if needed
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
# keep logs in individual directories per study
if [[ ! -d ${repo_root}/logs/${study} ]]; then
	mkdir "$repo_root"/logs/"$study"
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
bash "$repo_root"/individual_modules/run_transcription_pull.sh "$data_root" "$study" "$transcribeme_username" "$transcribeme_password"
echo ""
echo "Transcript pull complete"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# put copies of any newly reviewed transcripts (returned via Lochness) from raw to appropriate processed folder location here
# info on newly reviewed transcripts also appended to email
bash "$repo_root"/individual_modules/run_transcription_review_update.sh "$data_root" "$study" 
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
echo "Emailing status update to lab"
# in future will want to improve how we implement the email list, may be different for different studies
# also may want to improve how we do the subject line so it's less repetitive (include date info possibly? and/or give info on total number of new transcripts? even just study name?)
mail -s "[Interview Transcript Pipeline Updates] New Transcripts Received from TranscribeMe" "$lab_email_list" < "$repo_root"/transcript_lab_email_body.txt
#rm "$repo_root"/transcript_lab_email_body.txt # this will be created by wrapping transcript pull script, cleared out here after email sent
# for now don't delete the email, as it isn't sending on dev server. instead save it to logs folder
mv "$repo_root"/transcript_lab_email_body.txt "$repo_root"/logs/"$study"/transcript_lab_email_body_"$log_timestamp".txt
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
