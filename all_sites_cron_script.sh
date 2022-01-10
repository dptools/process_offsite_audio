#!/bin/bash

# activate python environment
source activate audio_process

# run audio side code for each config
for file in /opt/software/process_offsite_audio/pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_audio_process.sh "$file"
done

# run transcript side code for each config
for file in /opt/software/process_offsite_audio/pronet_site_configs/*.sh; do
	bash /opt/software/process_offsite_audio/interview_transcript_process.sh "$file"
done