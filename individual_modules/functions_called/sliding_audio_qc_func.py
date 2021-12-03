#!/usr/bin/env python

# prevent librosa from logging a warning every time it is imported
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

import os
import pandas as pd
import numpy as np
from scipy.io import wavfile
import soundfile as sf
import librosa
import sys

def sliding_audio_qc(filename,savepath,window_size=0.05,window_increment=0.05):
	# specify column headers that will be used for every CSV
	headers=["minutes_start","minutes_end","overall_db","mean_flatness"]

	# read in audio
	try:
		data, fs = sf.read(filename)
	except:
		print("(" + filename + " is a corrupted audio file)")
		return 

	# get length info
	ns = data.shape[0]
	if ns == 0:
		# ignore empty audio - will want to log this for pipeline
		print("(" + filename + " audio is empty)")
		return

	# and check that the audio is mono - this is currently just meant for basic QC of overall file, not speaker separation
	try: # may not be a second shape number when file is mono
		cs = data.shape[1]
		if cs == 2:
			print("(" + filename + " is not mono)")
			# still process it as if it were mono though! 
			data = np.mean(data, axis=1)
	except: # now it is definitely mono, good to proceed
		pass

	# now proceed with analysis of just the one channel
	chan1 = data.flatten()
			
	# convert minute scale input to be sample rate
	window_size_bins = int(window_size * 60.0 * fs)
	window_increment_bins = int(window_increment * 60.0 * fs)

	# compute features
	chan1_rms_rolling = [np.sqrt(np.nanmean(np.square(chan1[i:i+window_size_bins]))) for i in range(0,len(chan1),window_increment_bins)]
	chan1_flatness_rolling = [round(np.nanmean(librosa.feature.spectral_flatness(y=chan1[i:i+window_size_bins])),5) for i in range(0,len(chan1),window_increment_bins)]
	minutes_bins = range(len(chan1_rms_rolling))
	minutes = [round(x*window_increment,3) for x in minutes_bins]
	end_minutes = [round(x + window_size,3) for x in minutes]

	# convert RMS to decibels
	ref_rms=float(2*(10**(-5)))
	c1_db = [round(20 * np.log10(x/ref_rms),2) for x in chan1_rms_rolling] 

	# construct and save CSV
	values = [minutes,end_minutes,c1_db,chan1_flatness_rolling]
	new_csv = pd.DataFrame()
	for i in range(len(headers)):
		h = headers[i]
		vals = values[i]
		new_csv[h] = vals
	new_csv.to_csv(savepath,index=False)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    try: # if extra arguments provided allow window settings to also be set via command line
    	sliding_audio_qc(sys.argv[1], sys.argv[2], window_size=float(sys.argv[3]), window_increment=float(sys.argv[4]))
    except:
    	sliding_audio_qc(sys.argv[1], sys.argv[2])