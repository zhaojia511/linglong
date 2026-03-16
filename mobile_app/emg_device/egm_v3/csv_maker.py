import os
import csv
from PyQt5 import QtCore 

def save_data_to_csv(self):
    # Ensure the Results directory exists
    os.makedirs("Results", exist_ok=True)

    timestamp = QtCore.QDateTime.currentDateTime().toString("yyyyMMdd_HHmmss")
    file_path = os.path.join("Results", f"Raw_EMG_Data_{timestamp}.csv")

    try:
        with open(file_path, mode='w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(["EMG Value"])
            for value in enumerate(self.compiled_data):
                writer.writerow([value])
        print(f"Data saved to {file_path}")
    except Exception as e:
        print(f"Failed to save data: {e}")
    return file_path