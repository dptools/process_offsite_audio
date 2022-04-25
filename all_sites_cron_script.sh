#!/bin/bash

# need to ensure that my account can write to processed folders, because Lochness does not always create the interview subfolders for a subject ID (needs to be one in GENERAL and PROTECTED)
# this is just a workaround for the dev server right now, for production we need to figure out an actual structure for file permissions (TODO)
sudo chmod -R 770 /opt/software/Pronet_data_sync/PHOENIX/*/*/processed

# stupid hack to deal with the old bad consent date names 
# because the plan for how we will handle this keeps changing it would be a waste of time to build into the code right now. waiting for others to get their story straight
sudo rm /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/PronetLA/raw/LA00090/interviews/transcripts/PronetLA_LA00090_interviewAudioTranscript_open_day44598_session001.txt 
sudo rm /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/PronetNN/raw/NN00004/interviews/transcripts/PronetNN_NN00004_interviewAudioTranscript_open_day44592_session001.txt 
sudo rm /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/PronetWU/raw/WU00079/interviews/transcripts/PronetWU_WU00079_interviewAudioTranscript_open_day44593_session001.txt 
sudo rm /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/PronetYA/raw/YA00015/interviews/transcripts/PronetYA_YA00015_interviewAudioTranscript_open_day44432_session001.txt

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
sudo chgrp -R pronet /opt/software/Pronet_data_sync/PHOENIX/*/*/processed/*
# similarly make sure for the box transfer folder!
sudo chgrp -R pronet /opt/software/Pronet_data_sync/PHOENIX/PROTECTED/box_transfer