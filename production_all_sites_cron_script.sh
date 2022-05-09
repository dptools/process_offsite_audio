#!/bin/bash

# TODO - figure out what prod-specific setup is required here to make sure dependencies are installed
# activate python environment
. /home/mme36/anaconda3/etc/profile.d/conda.sh
conda activate audio_process

# run audio side code for each config
for file in /opt/software/process_offsite_audio/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_audio_process.sh "$file"
done

echo ""
echo ""

# run transcript side code for each config
for file in /opt/software/process_offsite_audio/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_transcript_process.sh "$file"
done

echo ""
echo ""

# run video code for each config
for file in /opt/software/process_offsite_audio/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_video_process.sh "$file"
done

echo ""
echo ""

# run accounting summary compilation for each config
for file in /opt/software/process_offsite_audio/production_pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_summary_checks.sh "$file"
done

# at the end of the processing, make sure that all processed interview outputs created by my account are in the pronet group, so they can be appropriately synced back to datalake
# may get permission denied for some things, but only matters that things my account owns have the group correctly set
chgrp -R pronet /mnt/ProNET/Lochness/PHOENIX/*/*/processed/*/interviews
# similarly make sure for the box transfer folder!
chgrp -R pronet /mnt/ProNET/Lochness/PHOENIX/PROTECTED/box_transfer

# finally run the utility for stats combined across sites
bash /opt/software/process_offsite_audio/final_all_sites_utility.sh /mnt/ProNET/Lochness/PHOENIX mennis2@partners.org PronetProduction