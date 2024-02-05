#!/bin/bash

# call this with data root path and email addresses to send to
# assumes various functionality from larger pipeline was already run
pii_email_list="$1"
deid_email_list="$2"
mail_attach="$3" # use this to recognize Prescient vs Pronet, as they also have different mail commands

if [[ -z ${mail_attach} ]]; then 
	cur_server="Pronet"
else
	cur_server="Prescient"
fi

# get absolute path to directory the script is being run from, to access CSVs from the appropriate log folder
full_path=$(realpath $0)
launch_root=$(dirname $full_path)
repo_root="$launch_root"/..
# organized with subfolder according to date
cur_date=$(date +%Y%m%d)

# compute the user friendly summaries where available
python "$launch_root/helper_functions/figs_summary.py" "$repo_root"/logs/TOTAL/"$cur_date"/combined-QC.csv "$repo_root"/logs/TOTAL/"$cur_date" "$cur_server"
python "$launch_root/helper_functions/tables_summary.py" "$repo_root"/logs/TOTAL/"$cur_date"/combined-QC.csv "$repo_root"/logs/TOTAL/"$cur_date" "$cur_server"

# change directories now so the file paths don't sneak into the attachment names
cd "$repo_root"/logs/TOTAL/"$cur_date" 

# now can move on to sending emails
# note -A is the flag for mailx attachments on pronet, whereas is is -a on ERIS
# also in this version of the mail command, need to input dummy txt file to prevent command from stalling looking for a cc address
# (even though the txt will not appear in the email body)
# so initialize that first
echo "See attached" > dummy.txt

if [[ -z ${mail_attach} ]]; then 
	# then actually send SOP and file accounting email to those that can access PII
	mail -s "Weekly Pronet Interviews Accounting Log" -A all-SOP-warnings.csv -A all-processed-warnings.csv -A all-processed-accounting.csv "$pii_email_list" < dummy.txt

	# finally send combined QC email to the larger list - include additional summary stuff is above python script worked, checking for figs and then if not for tables
	if [[ -e all-dists-by-type.pdf ]]; then
		mail -s "Weekly Pronet Interviews AVL QC Compilation" -A key-stats-table-by-site-and-type.html -A all-dists-by-type.pdf -A open-dists-by-site.pdf -A psychs-dists-by-site.pdf -A extended-counts-table.html -A combined-QC.csv -A open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	elif [[ -e key-stats-table-by-site-and-type.html ]]; then
		mail -s "Weekly Pronet Interviews AVL QC Compilation" -A key-stats-table-by-site-and-type.html -A extended-counts-table.html -A combined-QC.csv -A open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	else
		mail -s "Weekly Pronet Interviews AVL QC Compilation" -A combined-QC.csv -A open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	fi
else
	# then actually send SOP and file accounting email to those that can access PII
	mail -s "Weekly Prescient Interviews Accounting Log" -a all-SOP-warnings.csv -a all-processed-warnings.csv -a all-processed-accounting.csv "$pii_email_list" < dummy.txt

	# finally send combined QC email to the larger list - again checking for python outputs
	if [[ -e all-dists-by-type.pdf ]]; then
		mail -s "Weekly Prescient Interviews AVL QC Compilation" -a key-stats-table-by-site-and-type.html -a all-dists-by-type.pdf -a open-dists-by-site.pdf -a psychs-dists-by-site.pdf -a extended-counts-table.html -a combined-QC.csv -a open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	elif [[ -e key-stats-table-by-site-and-type.html ]]; then
		mail -s "Weekly Prescient Interviews AVL QC Compilation" -a key-stats-table-by-site-and-type.html -a extended-counts-table.html -a combined-QC.csv -a open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	else
		mail -s "Weekly Prescient Interviews AVL QC Compilation" -a combined-QC.csv -a open-counts-by-subject.csv "$deid_email_list" < dummy.txt
	fi
fi

# remove useless txt
rm dummy.txt