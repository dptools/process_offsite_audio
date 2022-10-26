#!/bin/bash

# call this with data root path and email addresses to send to
# assumes various functionality from larger pipeline was already run
pii_email_list="$1"
deid_email_list="$2"

# get absolute path to directory the script is being run from, to access CSVs from the appropriate log folder
full_path=$(realpath $0)
launch_root=$(dirname $full_path)
repo_root="$launch_root"/..
# organized with subfolder according to date
cur_date=$(date +%Y%m%d)

# change directories first so the file paths don't sneak into the attachment names
cd "$repo_root"/logs/TOTAL/"$cur_date" 

# now can move on to sending emails
# note -A is the flag for mailx attachments on pronet, whereas is is -a on ERIS
# also in this version of the mail command, need to input dummy txt file to prevent command from stalling looking for a cc address
# (even though the txt will not appear in the email body)
# so initialize that first
echo "EOM" > dummy.txt

# then actually send SOP and file accounting email to those that can access PII
mail -s "Weekly AMPSCZ Interviews Accounting Log" -A all-SOP-warnings.csv -A all-processed-accounting.csv "$pii_email_list" < dummy.txt

# finally send combined QC email to the larger list
mail -s "Weekly AMPSCZ Interviews AVL QC Compilation" -A combined-QC.csv "$deid_email_list" < dummy.txt

# remove useless txt
rm dummy.txt