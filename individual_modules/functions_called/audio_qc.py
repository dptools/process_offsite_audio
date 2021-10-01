#!/usr/bin/env python

# setting at top of file for root path of data - will move to config later
data_root = "/data/sbdp/PHOENIX"

# prevent librosa from logging a warning every time it is imported
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

# actual imports
import os
import pandas as pd
import numpy as np
import soundfile as sf
import librosa
import sys

# function that focuses on mono overall recording audio to do basic QC for the offsites
def offsite_qc(study, OLID):
	# specify column headers that will be used for every CSV
	headers=["patient","filename","length(minutes)","stereo?","overall_db","amplitude_stdev","mean_flatness","max_flatness"]
	# initialize lists to fill in df
	patients=[]
	fnames=[]
	lengths=[]
	ster_bools=[] # expect it to always be mono, but double check
	gains=[]
	stds=[]
	# spectral flatness is between 0 and 1, 1 being closer to white noise. it is calculated in short windows by the package used, so trying both mean and max summaries.
	mean_flats=[]
	max_flats=[]

	try:
		# will remain focused on PROTECTED here, as the output will still contain dates and times at this stage
		os.chdir(os.path.join(data_root,"PROTECTED", study, OLID, "offsite_interview/processed/decrypted_audio"))
	except:
		print("Problem with input arguments, or haven't decrypted any audio files yet for this patient") # should never reach this error if calling via bash module
		return

	cur_files = os.listdir(".")
	cur_files.sort() # go in order, although can also always sort CSV later.
	if len(cur_files) == 0:
		print("No new files for this patient, skipping") # should never reach this error if calling via bash module
		return
	for filename in cur_files:
		if not filename.endswith(".wav"): # skip any non-audio files (and folders)
			continue

		try:
			data, fs = sf.read(filename)
		except:
			# ignore bad audio - will want to log this for pipeline
			print("(" + filename + " is a corrupted audio file)")
			continue 

		# get length info
		ns = data.shape[0]
		if ns == 0:
			# ignore empty audio - will want to log this for pipeline
			print("(" + filename + " audio is empty)")
			continue

		# add metadata info to lists for CSV
		patients.append(OLID)
		fnames.append(filename) # this will later be used to get DPDash formatted CSV for GENERAL
		
		# append length info
		sec = float(ns)/fs
		mins = sec/float(60)
		lengths.append(mins)

		try: # may not be a second shape number when file is mono
			cs = data.shape[1] # check number of channels
			if cs == 2: # if stereo calculate channel 2 properties, else append nans
				ster_bools.append(1)
				chan1 = data[:,0].flatten() # assume just chan 1 for now, but if anything shows up as stereo we may want to go back and add proper calculation of chan 2
			else:
				ster_bools.append(0)
				chan1 = data.flatten()
			vol = np.sqrt(np.mean(np.square(chan1)))
			gains.append(vol)
			stds.append(np.nanstd(chan1))
			spec_flat = librosa.feature.spectral_flatness(y=chan1)
			mean_flats.append(np.mean(spec_flat))
			max_flats.append(np.amax(spec_flat))
		except: # now it is definitely mono
			ster_bools.append(0)
			chan1 = data.flatten()
			vol = np.sqrt(np.mean(np.square(chan1)))
			gains.append(vol)
			stds.append(np.nanstd(chan1))
			spec_flat = librosa.feature.spectral_flatness(y=chan1)
			mean_flats.append(np.mean(spec_flat))
			max_flats.append(np.amax(spec_flat))
		
	# convert RMS to decibels
	ref_rms=float(2*(10**(-5)))
	db = [20 * np.log10(x/ref_rms) for x in gains] 

	# now prepare to save new CSV for this patient (or update existing CSV if there is one)
	os.chdir(os.path.join(data_root,"PROTECTED", study, OLID, "offsite_interview/processed"))

	# construct current CSV
	values = [patients, fnames, lengths, ster_bools, db, stds, mean_flats, max_flats]
	new_csv = pd.DataFrame()
	for i in range(len(headers)):
		h = headers[i]
		vals = values[i]
		new_csv[h] = vals

	# now save CSV
	output_path = study+"_"+OLID+"_offsiteInterview_audioQC_output.csv" 
	# (will keep naming convention analogous to diary audios for the combined offsite audio, if do single speaker audio QC later will specify that as such)
	if os.path.isfile(output_path): # concatenate with existing outputs if necessary
		old_df = pd.read_csv(output_path)
		join_csv=pd.concat([old_df, new_csv])
		join_csv.reset_index(drop=True, inplace=True)
		# drop any duplicates in case audio got decrypted a second time - shouldn't happen via pipeline
		join_csv.drop_duplicates(subset=["OLID", "filename"],inplace=True)
		join_csv.to_csv(output_path,index=False)
	else:
		new_csv.to_csv(output_path,index=False)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    offsite_qc(sys.argv[1], sys.argv[2])
