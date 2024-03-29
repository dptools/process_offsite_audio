import os
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from datetime import date

# in latest update added a couple more pages with new features: 
# words per turn, fraction of maximum speaker, ID of maximum speaker, study day interview is conducted
# mean face confidence score, minimum faces in a frame, maximum faces in a frame, transcribeme speaker count/maximum faces count
# so now each PDF contains 5 pages. for documentation on the original 3 pages see thesis and why these other features were added, see thesis PDF
def run_summary_operation_figs(input_csv,output_folder,cur_server):
	input_df = pd.read_csv(input_csv)
	input_df["total_words"] = input_df["num_words_S1"] + input_df["num_words_S2"] + input_df["num_words_S3"] # note if num subjects > 3 this will be off though
	input_df["total_turns"] = input_df["num_turns_S1"] + input_df["num_turns_S2"] + input_df["num_turns_S3"] # note if num subjects > 3 this will be off though
	input_df["inaudible_per_word"] = input_df["num_inaudible"]/input_df["total_words"]
	input_df["redacted_per_word"] = input_df["num_redacted"]/input_df["total_words"]
	input_df["words_per_turn"] = [x/y if not np.isnan(y) else np.nan for x,y in zip(input_df["total_words"].tolist(),input_df["total_turns"].tolist())]
	input_df["max_speaker_words"] = [max(x,y,z) if not np.isnan(x) else np.nan for x,y,z in zip(input_df["num_words_S1"].tolist(),input_df["num_words_S2"].tolist(),input_df["num_words_S3"].tolist())]
	input_df["speech_balance"] = [x/y if not np.isnan(y) else np.nan for x,y in zip(input_df["max_speaker_words"].tolist(),input_df["total_words"].tolist())]
	input_df["max_speaker_id"] = [[x,y,z].index(max(x,y,z)) + 1 if not np.isnan(x) else np.nan for x,y,z in zip(input_df["num_words_S1"].tolist(),input_df["num_words_S2"].tolist(),input_df["num_words_S3"].tolist())]
	input_df["transcript_video_participants_ratio"] = [x/y if not (np.isnan(x) or np.isnan(y) or y==0) else np.nan for x,y in zip(input_df["num_subjects"].tolist(),input_df["maximum_faces_detected_in_frame"].tolist())]

	key_features_list = [["length_minutes","mean_faces_detected_in_frame","inaudible_per_word","redacted_per_word"],
						 ["num_subjects","total_words","num_inaudible","num_redacted"],
						 ["overall_db","mean_flatness","total_turns","mean_face_area"],
						 ["words_per_turn","speech_balance","max_speaker_id","day"],
						 ["mean_face_confidence_score","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","transcript_video_participants_ratio"]]
	# first pass at defining the actual bins instead (for some, for others still give n bins)
	n_bins_list = [[[0,5,10,15,20,30,40,50,60,90,120,180],[0,0.5,0.9,1.1,1.5,1.8,2.1,2.3,2.8,3.1,3.5,4],[0,0.001,0.005,0.01,0.02,0.03,0.04,0.05],[0,0.001,0.0025,0.005,0.01,0.015,0.02,0.025]],
				   [[0,2,3,4,5],30,30,30],[[20,40,50,55,60,65,70,75,80,85,100],30,30,30],[30,[0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0],[1,2,3,4],list(range(1,365,14))],
				   [[0.5,0.75,0.8,0.85,0.9,0.95,0.99,1.0],[0,1,2,3,4],[0,1,2,3,4,5,6],[0,0.25,0.33,0.5,0.66,0.75,1.0,1.33,1.5,2.0,3.0,4.0]]]
	cur_date = date.today().strftime("%m/%d/%Y")

	combined_pdf = PdfPages(os.path.join(output_folder,"all-dists-by-type.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [input_df[input_df["interview_type"]=="open"][key_features[i]].tolist(), input_df[input_df["interview_type"]=="psychs"][key_features[i]].tolist()]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=["open", "psychs"], edgecolor = "black")
			cur_ax.legend()
			cur_ax.set_title(key_features[i])
			try:
				low_lim = cur_bins[0]
				high_lim = cur_bins[-1]
				outer_count = str(input_df[(input_df[key_features[i]] < low_lim) | (input_df[key_features[i]] > high_lim)].shape[0])
				xname = "Interview Count (" + outer_count + " outside of range)"
				yname = "Value (using predefined bins - upper edge exclusive)"
				cur_ax.set_yticks(cur_bins)
			except:
				xname = "Interview Count"
				yname = "Value (using " + str(cur_bins) + " autogenerated bins)"
			cur_ax.set_xlabel(xname)
			cur_ax.set_ylabel(yname)
			max_x = cur_ax.get_xlim()[-1]
			if max_x > 100:
				x_ticks_list = list(range(0,100,5))
				x_ticks_list.extend(list(range(100,int(max_x)+1,15)))
				cur_ax.set_xticks(x_ticks_list)
				for tick in cur_ax.get_xticklabels():
					tick.set_rotation(45)
			else:
				cur_ax.set_xticks(range(0,int(max_x)+1,5))
			cur_ax.grid(color="#d3d3d3")
			cur_ax.set_axisbelow(True)

		fig.suptitle(cur_server + " AVL QC Distributions - stacked histograms by interview type" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		combined_pdf.savefig()
	combined_pdf.close()

	open_only = input_df[input_df["interview_type"]=="open"]
	psychs_only = input_df[input_df["interview_type"]=="psychs"]
	site_list = list(set(input_df["study"].tolist()))
	site_list.sort()
	site_names = [x[-2:] for x in site_list]
	open_n_bins_list = [[[0,5,10,15,20,25,30,40,60,120],[0,0.5,0.9,1.1,1.5,1.8,2.1,2.3,3],[0,0.001,0.005,0.01,0.02,0.03,0.04,0.05],[0,0.001,0.0025,0.005,0.01,0.015,0.02,0.025]],
						[[0,2,3,4],30,30,30],[[20,40,50,55,60,65,70,75,80,85,100],30,30,30],[50,[0.45,0.5,0.6,0.7,0.8,0.9,1.0],[1,2,3,4],list(range(1,240,14))],
						[[0.5,0.75,0.8,0.85,0.9,0.95,0.99,1.0],[0,1,2,3,4],[0,1,2,3,4],[0,0.33,0.5,0.66,1.0,1.5,2.0,3.0]]]
	psychs_n_bins_list = [[[0,20,30,40,50,60,90,120,180],[0,0.5,0.9,1.1,1.5,1.8,2.1,2.3,2.8,3.1,3.5,4],[0,0.001,0.005,0.01,0.02,0.03,0.04,0.05],[0,0.001,0.0025,0.005,0.01,0.015,0.02,0.025]],
						  [[0,2,3,4,5],30,30,30],[[20,40,50,55,60,65,70,75,80,85,100],30,30,30],[15,[0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0],[1,2,3,4],list(range(1,365,14))],
						  [[0.5,0.75,0.8,0.85,0.9,0.95,0.99,1.0],[0,1,2,3,4],[0,1,2,3,4,5,6],[0,0.25,0.33,0.5,0.66,0.75,1.0,1.33,1.5,2.0,3.0,4.0]]]

	# add hatches to avoid color repeat confusion
	# max number of sites for a given server will be below 30, colors repeat after 10
	# so need at most 2 hatches, presently only need 1
	# site assignments will change from week to week as new sites get added, because the sort is alphabetical
	if len(site_list) > 20:
		hatch_list = ['' for x in range(10)]
		hatch_list.extend(['...' for x in range(10)])
		hatch_list.extend(['xxx' for x in range(len(site_list)-20)])
	elif len(site_list) > 10:
		hatch_list = ['' for x in range(10)]
		hatch_list.extend(['...' for x in range(len(site_list)-10)])
	else:
		hatch_list = ['' for x in range(len(site_list))]

	open_pdf = PdfPages(os.path.join(output_folder,"open-dists-by-site.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = open_n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [open_only[open_only["study"]==x][key_features[i]].tolist() for x in site_list]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_n_output, cur_bins_output, cur_patches = cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=site_names, edgecolor = "black")
			for p in range(len(cur_patches)):
				patch = cur_patches[p]
				hatch = hatch_list[p]
				for cur_bar in patch:
					cur_bar.set(hatch = hatch)
			cur_ax.legend()
			cur_ax.set_title("open " + key_features[i])
			try:
				low_lim = cur_bins[0]
				high_lim = cur_bins[-1]
				outer_count = str(open_only[(open_only[key_features[i]] < low_lim) | (open_only[key_features[i]] > high_lim)].shape[0])
				xname = "Interview Count (" + outer_count + " outside of range)"
				yname = "Value (using predefined bins - upper edge exclusive)"
				cur_ax.set_yticks(cur_bins)
			except:
				xname = "Interview Count"
				yname = "Value (using " + str(cur_bins) + " autogenerated bins)"
			cur_ax.set_xlabel(xname)
			cur_ax.set_ylabel(yname)
			max_x = cur_ax.get_xlim()[-1]
			if max_x > 100:
				x_ticks_list = list(range(0,100,5))
				x_ticks_list.extend(list(range(100,int(max_x)+1,15)))
				cur_ax.set_xticks(x_ticks_list)
				for tick in cur_ax.get_xticklabels():
					tick.set_rotation(45)
			else:
				cur_ax.set_xticks(range(0,int(max_x)+1,5))
			cur_ax.grid(color="#d3d3d3")
			cur_ax.set_axisbelow(True)

		fig.suptitle(cur_server + " OPEN interview AVL QC Distributions - stacked histograms by site" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		open_pdf.savefig()
	open_pdf.close()

	psychs_pdf = PdfPages(os.path.join(output_folder,"psychs-dists-by-site.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = psychs_n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [psychs_only[psychs_only["study"]==x][key_features[i]].tolist() for x in site_list]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_n_output, cur_bins_output, cur_patches = cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=site_names, edgecolor = "black")
			for p in range(len(cur_patches)):
				patch = cur_patches[p]
				hatch = hatch_list[p]
				for cur_bar in patch:
					cur_bar.set(hatch = hatch)
			cur_ax.legend()
			cur_ax.set_title("psychs " + key_features[i])
			try:
				low_lim = cur_bins[0]
				high_lim = cur_bins[-1]
				outer_count = str(psychs_only[(psychs_only[key_features[i]] < low_lim) | (psychs_only[key_features[i]] > high_lim)].shape[0])
				xname = "Interview Count (" + outer_count + " outside of range)"
				yname = "Value (using predefined bins - upper edge exclusive)"
				cur_ax.set_yticks(cur_bins)
			except:
				xname = "Interview Count"
				yname = "Value (using " + str(cur_bins) + " autogenerated bins)"
			cur_ax.set_xlabel(xname)
			cur_ax.set_ylabel(yname)
			max_x = cur_ax.get_xlim()[-1]
			if max_x > 100:
				x_ticks_list = list(range(0,100,5))
				x_ticks_list.extend(list(range(100,int(max_x)+1,15)))
				cur_ax.set_xticks(x_ticks_list)
				for tick in cur_ax.get_xticklabels():
					tick.set_rotation(45)
			else:
				cur_ax.set_xticks(range(0,int(max_x)+1,5))
			cur_ax.grid(color="#d3d3d3")
			cur_ax.set_axisbelow(True)

		fig.suptitle(cur_server + " PSYCHS interview AVL QC Distributions - stacked histograms by site" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		psychs_pdf.savefig()
	psychs_pdf.close()

	return

if __name__ == '__main__':
	# Map command line arguments to function arguments
	run_summary_operation_figs(sys.argv[1], sys.argv[2], sys.argv[3])