import os
import sys
import csv
import asyncio
from matplotlib import pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from PyQt5 import QtCore, QtWidgets
from PyQt5.QtWidgets import QApplication, QStyle
from bleak import BleakClient, BleakScanner
from PyQt5.QtGui import QFont
from consts import ConstValues
from qasync import QEventLoop, asyncSlot



class EmgAPP(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.compiled_data = []
        
        self.setup_ui()
        self.plot_data()  

    def setup_ui(self):
        self.setWindowTitle("EMG Application")
        self.resize(1123, 895)
        self.central_widget = QtWidgets.QWidget(self)
        self.setCentralWidget(self.central_widget)

        self.layout = QtWidgets.QVBoxLayout(self.central_widget) 
        self.setup_buttons()
        self.setup_canvas() 
        self.setup_connections() 
        

    def setup_buttons(self):
        self.button_layout = QtWidgets.QHBoxLayout()
        
        self.scan_button = QtWidgets.QPushButton("Scan Device")
        self.scan_button.setFixedSize(150, 30)
        
        self.status_label = QtWidgets.QLabel("No Bluetooth device connected")
        self.status_label.setFont(QFont("Arial", weight=QFont.Bold))
        
        self.d_info_button = QtWidgets.QPushButton("Device Info")
        self.d_info_button.setFixedSize(100, 30)
        
        self.start_button = QtWidgets.QPushButton("Start Test")
        self.start_button.setFixedSize(100, 30)
        self.start_button.setEnabled(False)
        
        self.stop_button = QtWidgets.QPushButton("Stop Test")
        self.stop_button.setFixedSize(100, 30)
        self.stop_button.setEnabled(False)
        
        self.save_data_toggle = QtWidgets.QCheckBox("Save file")
        self.save_data_toggle.setChecked(False)
        
        self.dropdown_button = QtWidgets.QPushButton()
        self.dropdown_button.setFixedSize(30, 30)
        icon = QApplication.style().standardIcon(QStyle.SP_DirIcon)
        self.dropdown_button.setIcon(icon)
        
        self.dropdown_menu = QtWidgets.QMenu()
        self.save_data_action = QtWidgets.QWidgetAction(self.dropdown_menu)
        self.save_data_action.setDefaultWidget(self.save_data_toggle)
        self.dropdown_menu.addAction(self.save_data_action)
        self.dropdown_button.setMenu(self.dropdown_menu)
        
        self.button_layout.addWidget(self.scan_button)
        self.button_layout.addWidget(self.status_label)
        self.button_layout.addWidget(self.d_info_button)
        self.button_layout.addWidget(self.start_button)
        self.button_layout.addWidget(self.stop_button)
        self.button_layout.addWidget(self.dropdown_button)
        
        self.layout.addLayout(self.button_layout)
    
    
    def setup_canvas(self):
        self.figure = plt.figure()
        self.canvas = FigureCanvas(self.figure)
    
        self.layout.addWidget(self.canvas)
    
    
    def setup_connections(self):
        self.scan_button.clicked.connect(self.ble_connection_toggle)
        self.d_info_button.clicked.connect(self.send_command)
        self.start_button.clicked.connect(self.subscribe_to_notifications_2)
        self.stop_button.clicked.connect(self.unsubscribe_from_notification_2)
        
    # --------------- Ui setup end ---------------
        
    @asyncSlot()
    async def ble_connection_toggle(self):
        if not hasattr(self, 'client') or not self.client.is_connected:
            await self.scan_devices()
        else:
            await self.disconnect_device()
            
    
    
    @asyncSlot()
    async def scan_devices(self):
        self.status_label.setText("Scanning for devices...")
        devices = await BleakScanner.discover()
        for d in devices:
            if d.name in ("MED-S", "MED-P"):
                self.d_name = d.name
                self.status_label.setText(f"Connecting to {self.d_name}")
                await self.connect_to_device(d.address)
                return
        self.status_label.setText("Target device not found.")
    
    
    
    @asyncSlot()
    async def connect_to_device(self,address):
        self.client = BleakClient(address)
        try:
            await self.client.connect()
            self.scan_button.setText("Disconnect")
            self.status_label.setText(f"Connected to {self.d_name}")
            self.subscribe_to_notifications_1()
            return self.client
        except Exception as e:
            self.status_label.setText(f"Failed to connect: {e}")
            return None
        
        
    
    @asyncSlot()
    async def subscribe_to_notifications_1(self):
        def handle_notify(sender, data):
            self.parse_device_info(data)
            QtWidgets.QMessageBox.information(self, "Device Info", f"Version: {self.version}\nDirection: {self.direction}\nThreshold: {self.threshold}")

        try:
            await self.client.start_notify(ConstValues.NOTIFY_CHAR_UUID, handle_notify)
            self.status_label.setText(f"Get device info to enable Test")
        except Exception as e:
            self.status_label.setText(f"Failed to get device info: {e}")



    @asyncSlot()
    async def subscribe_to_notifications_2(self):
        self.compiled_data = []
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        # Start QTimer for plot update
        self.plot_timer = QtCore.QTimer()
        self.plot_timer.timeout.connect(self.plot_data)
        self.plot_timer.start(20) # plot refresh rate 50hz   
        
        def handle_notify(sender, data):
            threshold = self.threshold
            emg_values = self.parse_show_data(data, threshold)
            for value in emg_values:
                self.compiled_data.append(value)
        try:
            await self.client.start_notify(ConstValues.DATA_CHAR_UUID, handle_notify)
            self.status_label.setText(f"Receiving data from {self.d_name}...")
        except Exception as e:
            print(f"Failed to subscribe to notifications for DATA_CHAR_UUID: {e}")
            
          
    @asyncSlot()
    async def unsubscribe_from_notification_2(self):
        try:
            await self.client.stop_notify(ConstValues.DATA_CHAR_UUID)
            self.status_label.setText(f"Stopped receiving data from {self.d_name}")
            if self.save_data_toggle.isChecked():
                self.save_data_to_csv()
            self.stop_button.setEnabled(False)
            self.start_button.setEnabled(True)
            if hasattr(self, 'plot_timer'):
                self.plot_timer.stop()
        except Exception as e:
            print(f"Failed to unsubscribe from notifications for DATA_CHAR_UUID: {e}")
            


    @asyncSlot()
    async def send_command(self):
        try:
            await self.client.write_gatt_char(ConstValues.COMMAND_CHAR_UUID, ConstValues.COMMAND_HEX)
        except Exception as e:
            print(f"Failed to send command: {e}")
            
            
            
    def parse_device_info(self,raw_bytes: bytes):
        val = bytearray(raw_bytes)

        # According to the provided documentation, 
        # Find the delimiter: [0x0A, 0x00, 0x00]
        delimiter_index = -1
        for i in range(len(val) - 2):
            if val[i] == 0x0A and val[i+1] == 0x00 and val[i+2] == 0x00:
                delimiter_index = i
                break

        if delimiter_index == -1:
            raise ValueError("Delimiter not found in device info data")

        # UUID is from start to 6 bytes before delimiter
        uuid_bytes = val[0:delimiter_index - 6]
        uuid_str = ''.join(f'{b:02X}' for b in uuid_bytes)

        # Device version: S or P
        version_byte = val[delimiter_index - 6]
        self.version = 'S' if version_byte == ord('S') else 'P'

        # Direction: ASCII '0' is 48; subtract 48
        direction_byte = val[delimiter_index - 5]
        self.direction = 'Left' if direction_byte == 48 else 'Right'

        # Threshold: 4 ASCII bytes before delimiter
        threshold_bytes = val[delimiter_index - 4:delimiter_index]
        threshold_str = ''.join(str(b - 48) for b in threshold_bytes)
        self.threshold = int(threshold_str)
        self.start_button.setEnabled(True)
        return None
        
            
    def parse_show_data(self,raw_bytes: bytes, threshold: int) -> list:
        # Convert to byte array and skip the first 5 byte
        data = raw_bytes[5:]
        
        results = []
        for i in range(0, len(data), 2):
            if i + 1 < len(data):
                # Combine two bytes into a 16-bit integer (little endian)
                value = data[i] + (data[i + 1] << 8)
                # Subtract threshold
                adjusted_value = value - threshold
                results.append(adjusted_value)
        return results
            
            
            
    @asyncSlot()
    async def disconnect_device(self):
        try:
            await self.client.disconnect()
            self.status_label.setText("No Bluetooth device connected")
            self.scan_button.setText("Scan Device")
            self.start_button.setEnabled(False)
            self.stop_button.setEnabled(False)
        except Exception as e:
            print(f"Failed to disconnect: {e}")
        if hasattr(self, 'plot_timer'):
            self.plot_timer.stop()
            
       
       
    def plot_data(self):
        self.figure.clear()
        ax = self.figure.add_subplot(111)

        # show the last 5000 data points or all if less than 5000
        data_to_plot = self.compiled_data[-5000:] if len(self.compiled_data) > 5000 else self.compiled_data 
        ax.set_xlim(0, 5000) 
        
        ax.plot(data_to_plot, label="EMG Signal", linewidth=1.5)
        ax.set_title("EMG Signal Over Time")
        ax.set_xlabel("Sample Index")
        ax.set_ylabel("EMG Value (Threshold Adjusted)")
        ax.grid(True)
        ax.legend(loc="upper right")
        self.canvas.draw()
        
        
        
    def save_data_to_csv(self):
        if self.save_data_toggle.isChecked():
            # Ensure the Results directory exists
            os.makedirs("Results", exist_ok=True)

            timestamp = QtCore.QDateTime.currentDateTime().toString("yyyyMMdd_HHmmss")
            file_path = os.path.join("Results", f"EMG_Data_{timestamp}.csv")

            try:
                with open(file_path, mode='w', newline='') as file:
                    writer = csv.writer(file)
                    writer.writerow(["EMG Value"])
                    for index, value in enumerate(self.compiled_data):
                        writer.writerow([value])
                print(f"Data saved to {file_path}")
            except Exception as e:
                print(f"Failed to save data: {e}")
                
    def closeEvent(self, event):
        # Stop the plot timer if it exists
        if hasattr(self, 'plot_timer'):
            self.plot_timer.stop()
        # Disconnect from the device if connected
        if hasattr(self, 'client') and self.client.is_connected:
            asyncio.run(self.disconnect_device())
        event.accept()
    


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    main_window = EmgAPP()
    main_window.show()
    with loop:
        sys.exit(loop.run_forever())