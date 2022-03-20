#!/bin/bash

# need to ensure that my account can write to processed folders, because Lochness does not always create the interview subfolders for a subject ID (needs to be one in GENERAL and PROTECTED)
# this is just a workaround for the dev server right now, for production we need to figure out an actual structure for file permissions (TODO)
sudo chmod -R 770 /opt/software/Pronet_data_sync/PHOENIX/*/*/processed

# activate python environment
. /home/mme36/anaconda3/etc/profile.d/conda.sh
conda activate audio_process

# run audio side code for each config
for file in /opt/software/process_offsite_audio/pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_audio_process.sh "$file"
done

# run transcript side code for each config
for file in /opt/software/process_offsite_audio/pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_transcript_process.sh "$file"
done

# run video code for each config
for file in /opt/software/process_offsite_audio/pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_video_process.sh "$file"
done

# at the end of the processing, make sure that all processed interview outputs are in the pronet group, so they can be appropriately synced back to datalake
# this is also a temporary workaround for dev server, prod plan TODO
sudo chgrp -R pronet /opt/software/Pronet_data_sync/PHOENIX/*/*/processed/*/interviews
# similarly make sure for the box transfer folder!
sudo chgrp -R pronet /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/box_transfer