#!/bin/bash

# activate python environment
. /opt/software/miniconda3/etc/profile.d/conda.sh 
conda activate audio_process

# run audio side code for each config
for file in /opt/software/process_offsite_audio/amp_scz_launch/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_audio_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run transcript side code for each config
for file in /opt/software/process_offsite_audio/amp_scz_launch/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_transcript_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run video code for each config
for file in /opt/software/process_offsite_audio/amp_scz_launch/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_video_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run accounting summary compilation for each config
for file in /opt/software/process_offsite_audio/amp_scz_launch/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_summary_checks.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# at the end of the processing, make sure that all processed interview outputs created by my account are in the pronet group, so they can be appropriately synced back to datalake
# may get permission denied for some things, but only matters that things my account owns have the group correctly set
chgrp -R pronet /mnt/ProNET/Lochness/PHOENIX/*/*/processed/*/interviews
# similarly make sure for the box transfer folder!
chgrp -R pronet /mnt/ProNET/Lochness/PHOENIX/PROTECTED/box_transfer

# finally run the utility for stats combined across sites
bash /opt/software/process_offsite_audio/amp_scz_launch/final_all_sites_utility.sh /mnt/ProNET/Lochness/PHOENIX "mennis2@partners.org,philip.wolff@yale.edu" PronetProduction

# run the weekly logging email if it is Monday!
# note that running the above final_all_sites_utility is necessary for the below to work, in addition to having run the rest of the pipeline (as it concats extra CSVs for this)
# this is only done for production
if [[ $(date +%u) == 1 ]]; then
	pii_email_list="mennis2@partners.org,pwolff@emory.edu,zarina.bilgrami@emory.edu"
	deid_email_list="mennis2@partners.org,pwolff@emory.edu,zarina.bilgrami@emory.edu,jtbaker@partners.org,eliebenthal@mclean.harvard.edu,sylvain.bouix@etsmtl.ca"
	bash /opt/software/process_offsite_audio/amp_scz_launch/weekly_logging_utility.sh "$pii_email_list" "$deid_email_list"
else # for troubleshooting/rapid iteration as well as better site progress tracking I send to myself the update daily
	pii_email_list="mennis2@partners.org"
	deid_email_list="mennis@g.harvard.edu"
	bash /opt/software/process_offsite_audio/amp_scz_launch/weekly_logging_utility.sh "$pii_email_list" "$deid_email_list"
fi

# and make sure logs are readable!
chgrp -R pronet /opt/software/process_offsite_audio/logs