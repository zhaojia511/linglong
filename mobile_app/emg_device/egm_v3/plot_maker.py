import libemg
import numpy as np
from consts import ConstValues

def plot_data(self, reset=False):
    if self.compiled_data is None:  
        self.compiled_data = []
    if reset:
        self.compiled_data = []
    self.figure.clear()
    ax = self.figure.add_subplot(111)

    # show the last 5000 data points or all if less than 5000
    data_to_plot = self.compiled_data[-(self.plot_range):] if len(self.compiled_data) > self.plot_range else self.compiled_data
    ax.set_xlim(0, self.plot_range)
    
    filter_on=self.bandpass_filter_toggle.isChecked() or self.low_pass_toggle.isChecked() or self.high_pass_toggle.isChecked() or self.notch_filter_toggle.isChecked()
    
    if len(data_to_plot) >100 and filter_on:
        emg_array = np.array(data_to_plot)
        fs = ConstValues.sampling_frequency 
        fi = libemg.filtering.Filter(sampling_frequency=fs)

        if self.bandpass_filter_toggle.isChecked():
            fi.install_filters({
                "name": "bandpass",
                "cutoff": [20, 350],
                "order": 4
            })
        if self.low_pass_toggle.isChecked():
            fi.install_filters({
                "name": "lowpass",
                "cutoff": 350,
                "order": 4
            })
        if self.high_pass_toggle.isChecked():
            fi.install_filters({
                "name": "highpass",
                "cutoff": 20,
                "order": 4
            })
        if self.notch_filter_toggle.isChecked():
            fi.install_filters({
                "name": "notch",
                "cutoff": 60, 
                "bandwidth": 5,
                "order": 2
            })
            
        filtered_emg = fi.filter(emg_array)
        filtered_list = filtered_emg.tolist()
        filtered_list = [round(x, 2) for x in filtered_emg.tolist()]
        if self.compeare_filter_toggle.isChecked():
            ax.plot(data_to_plot, label="Raw Signal", linewidth=1.5)        
        ax.plot(filtered_list, label="Filtered Signal", linewidth=1.5, color='navy')
        
    else:
        ax.plot(data_to_plot, label="Raw Signal", linewidth=1.5)
    ax.set_xlabel("Sample Index")
    ax.set_ylabel("EMG Value (Threshold Adjusted)")
    ax.grid(True)
    ax.legend(loc="upper right")
    self.canvas.draw()
    
    
    
    
    