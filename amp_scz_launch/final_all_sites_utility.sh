#!/bin/bash

# call this with data root path and email address to send to
data_root="$1"
summary_email_list="$2"
server_version="$3"
mail_attach="$4"

# get absolute path to dir script is being run from, to save history of emails in logs and find relevant functions
full_path=$(realpath $0)
launch_root=$(dirname $full_path)
repo_root="$launch_root"/..
func_root="$launch_root"/helper_functions

# make directory for logs if needed
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
# keep logs from this in a TOTAL folder
if [[ ! -d ${repo_root}/logs/TOTAL ]]; then
	mkdir "$repo_root"/logs/TOTAL
fi
# organize with subfolder according to date
cur_date=$(date +%Y%m%d)
if [[ ! -d ${repo_root}/logs/TOTAL/${cur_date} ]]; then
	mkdir "$repo_root"/logs/TOTAL/"$cur_date"
fi

# go through and concatenate the CSVs of interest, adding site/subject/interview type columns
python "$func_root"/concat_all_csvs_func.py "$data_root" "$repo_root"/logs/TOTAL/"$cur_date"

# now can initialize emails that will be sent - one will be "good" updates and one will be "bad". I will attach the created CSVs to these emails below, but also will put newest updates in email bodies via python script
echo "Interview pipeline code has completed the run across ${server_version} sites today. Any new processing/QC updates are summarized in this email body." > "$repo_root"/logs/TOTAL/"$cur_date"/all_pipeline_update_email.txt
echo "" >> "$repo_root"/logs/TOTAL/"$cur_date"/all_pipeline_update_email.txt
echo "Interview pipeline code has completed the run across ${server_version} sites today. New warnings detected are summarized in this email body (note it is not exhaustive, may need to refer to more detailed logs if something seems amiss)." > "$repo_root"/logs/TOTAL/"$cur_date"/all_warning_update_email.txt
echo "" >> "$repo_root"/logs/TOTAL/"$cur_date"/all_warning_update_email.txt

# finalize the email bodies
python "$func_root"/detect_all_updates_func.py "$repo_root"/logs/TOTAL/"$cur_date"

# now just send both!
# 6/2023 update: removing attachments from these emails in favor of only putting them on weekly alerts. 
# basic updated on pipeline running each day will still be sent as email bodies though. code otherwise remains the same.
cd "$repo_root"/logs/TOTAL/"$cur_date" # change directories first 
echo "" >> all_pipeline_update_email.txt
echo "" >> all_pipeline_update_email.txt
echo "" >> all_warning_update_email.txt
echo "" >> all_warning_update_email.txt
# actually send the email bodies now 
mail -s "[${server_version}] Interview Pipeline Daily Stats Email"  "$summary_email_list" < all_pipeline_update_email.txt
mail -s "[${server_version}] Interview Pipeline Daily Warnings Email" "$summary_email_list" < all_warning_update_email.txt
