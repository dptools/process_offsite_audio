#!/bin/bash

# top level pipeline script for video side processing
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
	echo "Invalid data root path ${data_root} or study ID  ${study}"
	exit
fi
if [[ ! -d $study/raw ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
if [[ ! -d $study/processed ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
# don't care if there is a raw in GENERAL as I will never use that part, so excluding that check
if [[ ! -d ../GENERAL/$study/processed ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
if [[ ! -e ../GENERAL/${study}/${study}_metadata.csv ]]; then
	echo "Study ${study} missing metadata"
	exit
fi
cd "$study"/raw # switch to study's raw folder for first loop over patient list

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
exec >  >(tee -ia "$repo_root"/logs/"$study"/summary_check_logging_"$log_timestamp".txt)
exec 2> >(tee -ia "$repo_root"/logs/"$study"/summary_check_logging_"$log_timestamp".txt >&2)

# let user know script is starting
echo ""
echo "Beginning script - interview final summary/accounting for:"
echo "$study"
echo "with data root:"
echo "$data_root"

# setup processed folder (if necessary for new studies/patients)
# really this should never be needed as this should always run after the other pipeline steps, but keep in case (a few of the components here could work from only raw)
for p in *; do
	# check that it is truly a patient ID that has some interview data
	if [[ ! -d ${data_root}/PROTECTED/${study}/raw/${p}/interviews ]]; then
		continue
	fi

	# now need to make sure processed folders are setup for this patient in both PROTECTED and GENERAL
	# need patient folder under processed, and then also need interviews folder under patient (and psychs/open under interviews)
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p} ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p} ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews/open ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/open ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews/psychs ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/psychs ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs
	fi
done
cd "$data_root"/PROTECTED/"$study"/raw # ensure back to study's raw directory at end of loop

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# locate things under raw that do not match SOP for raw warning list
bash "$repo_root"/individual_modules/run_raw_folder_check.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# identify any new warnings both from newly processed files (check basic accounting and QC CSVs) and from newly detected SOP issues in raw
bash "$repo_root"/individual_modules/run_processed_accounting_check.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# if a summary stats email was initialized, it means there is some update for DPDash stats, so proceed with computing some summaries
if [[ -e "$repo_root"/summary_lab_email_body.txt ]]; then
	bash "$repo_root"/individual_modules/run_qc_site_stats.sh "$data_root" "$study"
	echo ""

	# add current time for runtime tracking purposes
	now=$(date +"%T")
	echo "Current time: ${now}"
	echo ""
fi

# finally send email if these was anything to email about
# doing warning email first if there were any
if [[ -e "$repo_root"/warning_lab_email_body.txt ]]; then
	echo "Emailing detected warnings to lab"
	mail -s "[ACTION REQUIRED] Issues Detected by ${study} ${server_version} Interview Pipeline" "$lab_email_list" < "$repo_root"/warning_lab_email_body.txt
	# move the email to logs folder for reference if there was actual content
	mv "$repo_root"/warning_lab_email_body.txt "$repo_root"/logs/"$study"/emails_sent/warning_lab_email_body_"$log_timestamp".txt
else
	echo "No new file accounting or major QC warnings for this study"
fi
echo ""
# now also send summary email if anything new was successfully processed
if [[ -e "$repo_root"/summary_lab_email_body.txt ]]; then
	echo "Emailing status updates to lab"
	mail -s "[${study} ${server_version} Interview Pipeline Updates] Latest QC Summary Stats" "$lab_email_list" < "$repo_root"/summary_lab_email_body.txt
	# move the email to logs folder for reference if there was actual content
	mv "$repo_root"/summary_lab_email_body.txt "$repo_root"/logs/"$study"/emails_sent/summary_lab_email_body_"$log_timestamp".txt
else
	echo "No new changes to processed file stats for this study"
fi
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
