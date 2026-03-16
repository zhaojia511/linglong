import sys
import asyncio
from PyQt5 import QtCore, QtWidgets
from bleak import BleakClient, BleakScanner
from PyQt5.QtGui import QFont
from consts import ConstValues
from qasync import QEventLoop, asyncSlot

from ui_elements import setup_buttons, setup_canvas, setup_connections
from decode_data import parse_device_info, parse_show_data
from plot_maker import plot_data
from csv_maker import save_data_to_csv


class EmgAPP(QtWidgets.QMainWindow):

    def __init__(self):
        super().__init__()
        self.compiled_data = []  # Initialize as empty list
        self.plot_range = 5000
        self.setup_ui()
        self.scan_devices()


    def setup_ui(self):
        self.setWindowTitle("EMG Application")
        self.resize(1123, 895)
        self.central_widget = QtWidgets.QWidget(self)
        self.setCentralWidget(self.central_widget)

        self.layout = QtWidgets.QVBoxLayout(self.central_widget) 
        setup_buttons(self)
        setup_canvas(self)
        plot_data(self)
        
        setup_connections(self)
        
        
    def update_plot_range_value(self, value):
        self.plot_range = value 
        plot_data(self)
        
    # --------------- Ui setup end ---------------
 
    # -------------- BLE setup start ---------------       
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
                self.status_label.setText(f"Connecting to {self.d_name}...")
                await self.connect_to_device(d.address)
                return
        self.status_label.setText("Target device not found.")
    
    
    @asyncSlot()
    async def connect_to_device(self,address):
        self.client = BleakClient(address)
        try:
            await self.client.connect()
            self.scan_button.setText("Disconnect")
            self.status_label.setText(f"Connected to {self.d_name}.")
            self.subscribe_to_notifications_1()
            return self.client
        except Exception as e:
            self.status_label.setText(f"Failed to connect: {e}")
            return None
        
            
    @asyncSlot()
    async def disconnect_device(self):
        try:
            self.status_label.setText(f"Disconnecting from {self.d_name}...")
            await self.client.disconnect()
            self.status_label.setText("No Bluetooth device connected")
            self.scan_button.setText("Scan Device")
            self.start_button.setEnabled(False)
            self.stop_button.setEnabled(False)
        except Exception as e:
            print(f"Failed to disconnect: {e}")
        if hasattr(self, 'plot_timer'):
            self.plot_timer.stop()
    
    
    @asyncSlot()
    async def subscribe_to_notifications_1(self):
        def handle_notify(sender, data):
            parse_device_info(self,data)
            QtWidgets.QMessageBox.information(self, "Device Info", f"Version: {self.version}\nDirection: {self.direction}\nThreshold: {self.threshold}")

        try:
            await self.client.start_notify(ConstValues.NOTIFY_CHAR_UUID, handle_notify)
            self.status_label.setText(f"Get device info to enable Test")
            self.d_info_button.setEnabled(True)
        except Exception as e:
            self.status_label.setText(f"Failed to get device info: {e}")


    @asyncSlot()
    async def subscribe_to_notifications_2(self):
        self.compiled_data = []  # Change this line (remove type annotation)
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        # Start QTimer for plot update
        self.plot_timer = QtCore.QTimer()
        self.plot_timer.timeout.connect(lambda: plot_data(self))
        self.plot_timer.start(20) 
        
        def handle_notify(sender, data):
            threshold = self.threshold
            emg_values = parse_show_data(self, data, threshold)
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
                file_path= save_data_to_csv(self)
                QtWidgets.QMessageBox.information(self, "Data Saved", f"Data saved to {file_path}")             
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
            
    # -------------- BLE setup end ---------------     
             
    def closeEvent(self, event):
        """Handle cleanup before the application closes."""
        try:
            # Unsubscribe from notifications if connected
            if hasattr(self, 'client') and self.client.is_connected:
                asyncio.run(self.unsubscribe_from_notification_2())
                asyncio.run(self.disconnect_device())
            
            # Stop the plot timer if active
            if hasattr(self, 'plot_timer') and self.plot_timer.isActive():
                self.plot_timer.stop()
        except Exception as e:
            print(f"Error during cleanup: {e}")
        finally:
            event.accept()  
        

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    main_window = EmgAPP()
    main_window.show()
    with loop:
        sys.exit(loop.run_forever())