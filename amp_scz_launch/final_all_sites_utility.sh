#!/bin/bash

# call this with data root path and email address to send to
data_root="$1"
summary_email_list="$2"
server_version="$3"

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
echo "Interview pipeline code has completed the run across ${server_version} sites today. Any new processing updates are reported on in this email body. CSVs combining all info to date from across sites are also attached - one containing patient and site level DPDash QC summary stats (open and psychs summarized separately) and one containing file accounting information for processed files (including name maps and the dates of various pipeline steps)." > "$repo_root"/logs/TOTAL/"$cur_date"/all_pipeline_update_email.txt
echo "" >> "$repo_root"/logs/TOTAL/"$cur_date"/all_pipeline_update_email.txt
echo "Interview pipeline code has completed the run across ${server_version} sites today. New warnings detected are reported on in this email body (note it is not exhaustive, may need to refer to more detailed logs if something seems amiss). CSVs combining all info to date from across sites are also attached - one containing any warnings related to file processing outputs and one containing any warnings related to raw file SOP violations." > "$repo_root"/logs/TOTAL/"$cur_date"/all_warning_update_email.txt
echo "" >> "$repo_root"/logs/TOTAL/"$cur_date"/all_warning_update_email.txt

# finalize the email bodies
python "$func_root"/detect_all_updates_func.py "$repo_root"/logs/TOTAL/"$cur_date"

# now just send both!
# note -A is the flag for mailx attachments on pronet, whereas is is -a on ERIS
cd "$repo_root"/logs/TOTAL/"$cur_date" # change directories first so the file paths don't sneak into the attachment names
# for some stupid reason it seems impossible to both have an email body and have email attachments with this version of mailx (apparently if using -A it is an outdated version?)
# tried many things so now just doing a workaround until the emails are nicer anyway (currently CSVs may be too dense)
echo "" >> all_pipeline_update_email.txt
echo "" >> all_pipeline_update_email.txt
echo "Note described attachments are being sent in a separate email (these and warning CSVs to all be attached, should be 4 updated records coming in a separate email)" >> all_pipeline_update_email.txt
echo "" >> all_warning_update_email.txt
echo "" >> all_warning_update_email.txt
echo "Note described attachments are being sent in a separate email (these and processed stat/accounting CSVs to all be attached, should be 4 updated records coming in a separate email)" >> all_warning_update_email.txt
# actually send the email bodies now first
mail -s "[${server_version}] Interview Pipeline Daily Stats Email"  "$summary_email_list" < all_pipeline_update_email.txt
mail -s "[${server_version}] Interview Pipeline Daily Warnings Email" "$summary_email_list" < all_warning_update_email.txt
# inputting the txt file here even though it won't show up in the email body, just to prevent command from stalling looking for a cc
mail -s "[${server_version}] Interview Pipeline Latest Attachments" -A all-QC-summary-stats.csv -A all-processed-accounting.csv -A all-processed-warnings.csv -A all-SOP-warnings.csv "$summary_email_list" < all_pipeline_update_email.txt
