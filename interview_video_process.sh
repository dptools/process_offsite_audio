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
if [[ ! -e ../PROTECTED/${study}/${study}_metadata.csv ]]; then
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
exec >  >(tee -ia "$repo_root"/logs/"$study"/video_process_logging_"$log_timestamp".txt)
exec 2> >(tee -ia "$repo_root"/logs/"$study"/video_process_logging_"$log_timestamp".txt >&2)

# let user know script is starting
echo ""
echo "Beginning script - interview video preprocessing for:"
echo "$study"
echo "with data root:"
echo "$data_root"

# setup processed folder (if necessary for new studies/patients)
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

bash "$repo_root"/individual_modules/run_new_video_extract.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# now run video QC
bash "$repo_root"/individual_modules/run_video_qc.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# finally send email if these was anything to email about
if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then
	echo "Emailing status update to lab"
	# first need to put together the rest of the email
	echo "--- Interview videos newly processed ---" >> "$repo_root"/video_lab_email_body.txt
	cat "$repo_root"/video_temp_process_list.txt >> "$repo_root"/video_lab_email_body.txt
	rm "$repo_root"/video_temp_process_list.txt
	echo "" >> "$repo_root"/video_lab_email_body.txt
	# also add a warning message so empty email has clear meaning
	echo "(if the above list is empty, a new video was recognized but processing code crashed - could be an issue with processing long videos on the limited compute of data aggregation server)" >> "$repo_root"/video_lab_email_body.txt
	# now send
	mail -s "[${study} ${server_version} Interview Pipeline Updates] New Video Processed" "$lab_email_list" < "$repo_root"/video_lab_email_body.txt
	# move the email to logs folder for reference if there was actual content
	mv "$repo_root"/video_lab_email_body.txt "$repo_root"/logs/"$study"/emails_sent/video_lab_email_body_"$log_timestamp".txt
else
	echo "No new video updates for this study, so no email to send"
fi
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# finally run the file accounting updates for this study
echo "Compiling/updating file lists with processing date"
bash "$repo_root"/individual_modules/run_final_video_accounting.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
