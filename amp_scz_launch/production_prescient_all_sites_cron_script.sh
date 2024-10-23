#!/bin/bash
PHOENIX_ROOT=/var/lib/prescient/data/PHOENIX
REPO_ROOT=/var/lib/prescient/soft/process_offsite_audio

# need to ensure that my account can write to processed folders, because Lochness does not always create the interview subfolders for a subject ID (needs to be one in GENERAL and PROTECTED)
#chmod -R 770 $PHOENIX_ROOT/*/*/processed
# needed to drop sudo though to prevent asking for password from stalling the cron. hopefully it works fine anyways!

# activate python environment
source ~/.bash_profile
source /var/lib/prescient/soft/miniconda3/etc/profile.d/conda.sh
conda activate /var/lib/prescient/soft/miniconda3/envs/audio_process

export PATH=/var/lib/prescient/soft/mail_utils:$PATH

# run audio side code for each config
for file in $REPO_ROOT/amp_scz_launch/production_prescient_site_configs/*.sh; do
	bash $REPO_ROOT/interview_audio_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run transcript side code for each config
for file in $REPO_ROOT/amp_scz_launch/production_prescient_site_configs/*.sh; do
	bash $REPO_ROOT/interview_transcript_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run video code for each config
for file in $REPO_ROOT/amp_scz_launch/production_prescient_site_configs/*.sh; do
	bash $REPO_ROOT/interview_video_process.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# run accounting summary compilation for each config
for file in $REPO_ROOT/amp_scz_launch/production_prescient_site_configs/*.sh; do
	bash $REPO_ROOT/interview_summary_checks.sh "$file"
	# add spacing for when monitoring logs in real time
	echo ""
	echo ""
done

# at the end of the processing, make sure that all processed interview outputs are in the pronet group, so they can be appropriately synced back to datalake
chgrp -R prescient $PHOENIX_ROOT/*/*/processed/*
# similarly make sure for the box transfer folder!
chgrp -R prescient $PHOENIX_ROOT/PROTECTED/box_transfer
#final permissions update
chmod -R 770 $PHOENIX_ROOT/*/*/processed

# finally run the utility for stats combined across sites
# bash $REPO_ROOT/amp_scz_launch/final_all_sites_utility.sh $PHOENIX_ROOT "HRAHIMIEICHI@partners.org,linying.li@emory.edu" PrescientProduction "yes"

# note Kevin's code now handles the Mediaflux push, so that is not needed here!

# run the weekly logging email if it is Monday!
# note that running the above final_all_sites_utility is necessary for the below to work, in addition to having run the rest of the pipeline (as it concats extra CSVs for this)
# this is only done for production
if [[ $(date +%u) == 1 ]]; then
	pii_email_list="sophie.tod@orygen.org.au,pwolff@emory.edu,zarina.bilgrami@emory.edu,linying.li@emory.edu,eliebenthal@mclean.harvard.edu,HRAHIMIEICHI@partners.org,dmohandass@mgh.harvard.edu,beau-luke.colton@orygen.org.au"
	deid_email_list="sophie.tod@orygen.org.au,pwolff@emory.edu,zarina.bilgrami@emory.edu,linying.li@emory.edu,eliebenthal@mclean.harvard.edu,HRAHIMIEICHI@partners.org,jtbaker@partners.org,sylvain.bouix@etsmtl.ca,dominic.dwyer@orygen.org.au,barnaby.nelson@orygen.org.au,dmohandass@mgh.harvard.edu,beau-luke.colton@orygen.org.au"
	bash /home/cho/soft/process_offsite_audio/amp_scz_launch/weekly_logging_utility.sh "$pii_email_list" "$deid_email_list" "yes"
fi

